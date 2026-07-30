#!/usr/bin/env python3
"""Validate the versioned PLAY-080 South zero-pixel prelock successor."""

from __future__ import annotations

import argparse
import copy
from dataclasses import dataclass
import errno
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import stat
import subprocess
import sys
from typing import Any


SOURCE_DIR = Path(__file__).resolve().parent
REPOSITORY_ROOT = SOURCE_DIR.parents[5]
SOURCE_ROOT = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-080/"
    "industrial-l04-south-source-v01"
)
EVIDENCE_ROOT = (
    "docs/production/evidence/PLAY-080/industrial-l04-south-source-v01"
)
HANDOFF_PATH = f"{SOURCE_ROOT}/prelock-successor-v01.json"
VALIDATOR_PATH = f"{SOURCE_ROOT}/validate_prelock_successor_v01.py"
PROOF_PATH = f"{EVIDENCE_ROOT}/PRELOCK-SUCCESSOR-V01-VALIDATION.json"
BRANCH = "codex/citysim-world-art-south"
PUBLISHED_MASTER = "642acc81992e5358768e71c4d8594b24c8d291a9"
PUBLISHED_MASTER_TREE = "b42e8b22ad13de7043c3f1077996ce8f646e052b"

CLAIM = {
    "authorityCommit": PUBLISHED_MASTER,
    "blobOid": "f58988aeeba6f034cc74b4a13a3336782eedaacb",
    "path": "docs/production/claims/PLAY-080.world-art-south.md",
    "role": "claim",
    "sha256": "6ccd0313c078b24fc1b1a42806434480f46fd9fe705dd51c26015b174be95973",
}
HARDENED_VERIFIER = {
    "authorityCommit": PUBLISHED_MASTER,
    "blobOid": "f9a62d73bebf407d5eb2859662589a5932876628",
    "path": f"{SOURCE_ROOT}/validate_literal192_frontage_fixtures.py",
    "role": "hardenedSemanticReplayVerifier",
    "sha256": "9c4d948395631bd10a594dd609c3c3ff692f49569fa2e6b34b271e5834976be4",
}
HARDENED_PROOF = {
    "authorityCommit": PUBLISHED_MASTER,
    "blobOid": "b3a982c3bb141c1c277ed162def3f3fb21553ee7",
    "path": f"{EVIDENCE_ROOT}/LITERAL-192-FRONTAGE-REPLAY-SAFETY-VALIDATION.json",
    "role": "hardenedSemanticReplayProof",
    "sha256": "7ab2ed1423a6775b0c1d2738ed8b4ac6d354bfd0fd4df4e82bb1e422acf1cf38",
}
RUNNER = {
    "authorityCommit": PUBLISHED_MASTER,
    "blobOid": "bde316b55999a03b63316e89b02cdd8443b0bc33",
    "path": f"{SOURCE_ROOT}/runner-contract.json",
    "role": "southPrelockRunner",
    "sha256": "bc74613e9fdcc5b7c378488b0a5c3b5404087fb231da2b528b719597a1df03a2",
    "state": "awaiting_appearance_lock",
}
SCENE = {
    "authorityCommit": PUBLISHED_MASTER,
    "blobOid": "d04d7630436430907caaeb4eaa9c2d04304190ad",
    "path": (
        "Native/CitySimNative/WorldArt/Blender/PLAY-080/"
        "industrial-l04-south-predesign-v01.scene.json"
    ),
    "role": "acceptedSouthScene",
    "sha256": "e0c8dd02f261844daa3d78ba05c482acbbe9b08eac835a0f863621f48010b07d",
}
MATERIALS = {
    "authorityCommit": PUBLISHED_MASTER,
    "blobOid": "3a11708434c1df4e85e699b84bcf7a88fbf439e9",
    "path": (
        "Native/CitySimNative/WorldArt/Blender/PLAY-080/"
        "industrial-l04-south-predesign-v01.materials.json"
    ),
    "role": "acceptedSouthMaterials",
    "sha256": "624b34f10354c79e0ced914ed55cf4dcb05468997d4efb679f881477984244fb",
}
CAMERA_SOCKET_HANDOFF = {
    "authorityCommit": PUBLISHED_MASTER,
    "blobOid": "5a8c8d27936327cb817ab36bfb7f2c33046f2a8e",
    "path": f"{EVIDENCE_ROOT}/PARALLEL-SOUTH-V2-ZERO-PIXEL-HANDOFF.json",
    "role": "cameraSocketHandoff",
    "sha256": "cb74072724e2d93b52183e64785662b65376f5beb2f24fd2d7521524f6664c32",
}
ACTUAL_CAMERA_PROOF = {
    "authorityCommit": PUBLISHED_MASTER,
    "blobOid": "5d419035fcfa21fc379cb8a9c355b4ca82d34049",
    "path": f"{EVIDENCE_ROOT}/BRIDGE-ADOPTION-ACTUAL-CAMERA-PROOF.json",
    "role": "actualCameraProof",
    "sha256": "803ddde64049178a7a2ecda3ac14f228e6150bfc819d19ee9995be1ed52d7d4a",
}
BRIDGE_MAPPING = {
    "authorityCommit": PUBLISHED_MASTER,
    "blobOid": "2b82ae30e5468cd79dee29ef78ab8c41a20debcb",
    "path": (
        "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
        "industrial-l04-direction-bridge-v06/MAPPING-CONTRACT.json"
    ),
    "role": "directionBridgeV06",
    "sha256": "5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7",
}
SOURCE_STAGE_SCHEMA = {
    "authorityCommit": PUBLISHED_MASTER,
    "blobOid": "198937fd641a9e117a4e96136052ae8607025675",
    "draft": "https://json-schema.org/draft/2020-12/schema",
    "id": "citysim://integration/industrial-l04-source-stage-handoff-v2",
    "path": (
        "docs/production/evidence/INTEGRATION/"
        "industrial-l04-source-stage-handoff-schema-v2.json"
    ),
    "role": "sourceStageSchemaV2",
    "sha256": "93efe9ca6d000a2d145098f722338c8e85829d6de6724c3f231a93c06eadf3d7",
}
PUBLISHED_MASTER_RECORD = {
    "commit": PUBLISHED_MASTER,
    "role": "publishedMaster",
    "treeOid": PUBLISHED_MASTER_TREE,
}
PREDECESSOR_REPLAY = {
    "expectedAction": "VERIFIED_READ_ONLY",
    "expectedAdversarialCases": 14,
    "expectedOutputSha256": HARDENED_PROOF["sha256"],
    "proof": HARDENED_PROOF,
    "validator": HARDENED_VERIFIER,
}
EXPECTED_BRIDGE = {
    "acceptedCandidateCommit": "3e01ca6738d7574718f9aeff4b66771eee109feb",
    "axisOrder": [2, 0, 1],
    "axisSigns": [1, 1, 1],
    "determinant": 1,
    "formula": "B(CitySim[x,y,z])=Blender[z,x,y]",
    "mappingContract": BRIDGE_MAPPING,
    "matrixRows": [[0, 0, 1], [1, 0, 0], [0, 1, 0]],
    "sourceOrder": [0, 1, 2, 3],
    "state": "v06_revalidated",
}
EXPECTED_CAMERA_SOCKET = {
    "actualSourceSocketPixels": [640.0000305175781, 832.0001525878906],
    "blenderNativeSouthSocket": [28, 0, 0],
    "canonicalCitySimSouthSocket": [0, 0, 28],
    "maximumDeltaSourcePixels": 0.000152587890625,
    "sourceSouthSocketPixels": [640, 832],
    "toleranceSourcePixels": 0.001,
}
MISSING_AUTHORITIES = {
    "appearanceLock": {
        "appearanceLockCommit": None,
        "appearanceLockSha256": None,
        "documentPath": None,
        "northProcessADecodedRgbaSha256": None,
        "northProcessASourceSha256": None,
    },
    "postLockProductionAuthority": {
        "commit": None,
        "path": None,
        "sha256": None,
    },
    "sourceProductionProfile": {
        "commit": None,
        "path": None,
        "sha256": None,
    },
}
EXPECTED_GATES = {
    "admissionAuthorized": False,
    "candidateReadyForIndependentReview": False,
    "dccAuthorized": False,
    "integrationAdmitted": False,
    "pixelProductionAuthorized": False,
    "processA": "not_run",
    "processB": "not_run",
    "processC": "not_run",
    "productionSelected": False,
    "rendererQuarantined": False,
    "shippingAuthorized": False,
    "sourceReady": False,
}
EXPECTED_ACTIVITY = {
    "blenderProcessLaunches": 0,
    "blenderRenderApiCalls": 0,
    "contactSheetInvocations": 0,
    "dccProcessLaunches": 0,
    "imageGenInvocations": 0,
    "normalizerInvocations": 0,
    "pixelFiles": 0,
    "renderInvocations": 0,
    "sourcePackets": 0,
}
EXPECTED_OUTPUTS = {
    "handoff": HANDOFF_PATH,
    "proof": PROOF_PATH,
    "validator": VALIDATOR_PATH,
}
EXPECTED_CASES = {
    "stale-published-master": (
        "STALE_PUBLISHED_MASTER",
        "/publishedMaster/commit",
    ),
    "stale-hardened-verifier": (
        "STALE_HARDENED_VERIFIER",
        "/predecessorReplay/validator/sha256",
    ),
    "stale-runner": ("STALE_RUNNER", "/runner/sha256"),
    "wrong-claim": ("WRONG_CLAIM", "/claim/sha256"),
    "wrong-bridge": ("WRONG_BRIDGE", "/bridge/mappingContract/sha256"),
    "wrong-south-socket": (
        "WRONG_SOUTH_SOCKET",
        "/cameraSocket/canonicalCitySimSouthSocket",
    ),
    "sibling-path-substitution": (
        "SIBLING_PATH_SUBSTITUTION",
        "/acceptedSouth/scene/path",
    ),
    "orientation-transform": (
        "ORIENTATION_TRANSFORM_FORBIDDEN",
        "/orientationTransform",
    ),
    "unsafe-output": ("UNSAFE_OUTPUT_PATH", "/outputs/proof"),
}
BASE_BINDINGS = [
    CLAIM,
    HARDENED_VERIFIER,
    HARDENED_PROOF,
    RUNNER,
    SCENE,
    MATERIALS,
    CAMERA_SOCKET_HANDOFF,
    ACTUAL_CAMERA_PROOF,
    BRIDGE_MAPPING,
    SOURCE_STAGE_SCHEMA,
]


class SuccessorRejected(RuntimeError):
    """Fail-closed successor validation rejection."""

    def __init__(self, code: str, details: Any = None):
        super().__init__(code)
        self.code = code
        self.details = details


@dataclass(frozen=True)
class CapturedFile:
    raw: bytes
    identity: tuple[int, int, int, int, int]


def reject(code: str, details: Any = None) -> None:
    raise SuccessorRejected(code, details)


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


def canonical_bytes(value: dict[str, Any]) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


def sha256_bytes(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


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
    relative_path: str, unsafe_code: str
) -> tuple[int, str]:
    pure = parse_safe_relative_path(relative_path, unsafe_code)
    flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
    descriptor = os.open(REPOSITORY_ROOT, flags)
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


def capture_repo_file(relative_path: str) -> CapturedFile:
    parent_descriptor, name = open_parent_descriptor(
        relative_path, "INPUT_UNSAFE_PARENT"
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


def write_exclusive_proof(raw: bytes) -> None:
    parent_descriptor, name = open_parent_descriptor(
        PROOF_PATH, "OUTPUT_UNSAFE_PARENT"
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
                reject("OUTPUT_EXISTS", PROOF_PATH)
            reject("OUTPUT_EXCLUSIVE_OPEN_FAILED", error.errno)
        offset = 0
        while offset < len(raw):
            offset += os.write(descriptor, raw[offset:])
        os.fsync(descriptor)
        os.lseek(descriptor, 0, os.SEEK_SET)
        captured = read_descriptor_bytes(descriptor)
        descriptor_stat = os.fstat(descriptor)
        entry = os.stat(name, dir_fd=parent_descriptor, follow_symlinks=False)
        if (
            descriptor_stat.st_dev != entry.st_dev
            or descriptor_stat.st_ino != entry.st_ino
            or not stat.S_ISREG(entry.st_mode)
            or captured != raw
        ):
            reject("OUTPUT_REPLACED", PROOF_PATH)
    finally:
        if descriptor >= 0:
            os.close(descriptor)
        os.close(parent_descriptor)


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


def validate_git_authorities() -> dict[str, Any]:
    branch = git_output("branch", "--show-current")
    if branch != BRANCH:
        reject("BRANCH_MISMATCH", {"expected": BRANCH, "actual": branch})
    commit = git_output("rev-parse", f"{PUBLISHED_MASTER}^{{commit}}")
    tree = git_output("rev-parse", f"{PUBLISHED_MASTER}^{{tree}}")
    if commit != PUBLISHED_MASTER or tree != PUBLISHED_MASTER_TREE:
        reject(
            "STALE_PUBLISHED_MASTER",
            {"commit": commit, "tree": tree},
        )
    git_output("merge-base", "--is-ancestor", PUBLISHED_MASTER, "HEAD")
    blobs: list[dict[str, str]] = []
    for binding in BASE_BINDINGS:
        actual_blob = git_output(
            "rev-parse", f"{PUBLISHED_MASTER}:{binding['path']}"
        )
        if actual_blob != binding["blobOid"]:
            reject(
                "BASE_BLOB_AUTHORITY_MISMATCH",
                {
                    "role": binding["role"],
                    "expected": binding["blobOid"],
                    "actual": actual_blob,
                },
            )
        blobs.append(
            {
                "blobOid": actual_blob,
                "path": binding["path"],
                "role": binding["role"],
            }
        )
    return {
        "blobAuthorities": blobs,
        "branch": branch,
        "publishedMaster": PUBLISHED_MASTER_RECORD,
        "runtimeHeadPolicy": "published-master-is-ancestor",
    }


def validate_handoff_identity(handoff: dict[str, Any]) -> None:
    require_exact_keys(
        handoff,
        {
            "acceptedSouth",
            "activity",
            "adversarialCases",
            "branch",
            "bridge",
            "cameraSocket",
            "claim",
            "direction",
            "disposition",
            "gates",
            "missingAuthorities",
            "mode",
            "orientationTransform",
            "outputs",
            "predecessorReplay",
            "publishedMaster",
            "runner",
            "schema",
            "sourceStageSchema",
            "stage",
            "taskId",
            "version",
        },
        "handoff",
    )
    if handoff["publishedMaster"] != PUBLISHED_MASTER_RECORD:
        reject("STALE_PUBLISHED_MASTER", handoff["publishedMaster"])
    if handoff["predecessorReplay"] != PREDECESSOR_REPLAY:
        reject("STALE_HARDENED_VERIFIER", handoff["predecessorReplay"])
    if handoff["runner"] != RUNNER:
        reject("STALE_RUNNER", handoff["runner"])
    if handoff["claim"] != CLAIM:
        reject("WRONG_CLAIM", handoff["claim"])
    if handoff["bridge"] != EXPECTED_BRIDGE:
        reject("WRONG_BRIDGE", handoff["bridge"])
    if handoff["cameraSocket"] != EXPECTED_CAMERA_SOCKET:
        reject("WRONG_SOUTH_SOCKET", handoff["cameraSocket"])
    accepted = handoff["acceptedSouth"]
    if (
        not isinstance(accepted, dict)
        or accepted.get("scene") != SCENE
        or accepted.get("materials") != MATERIALS
        or accepted.get("cameraSocketHandoff") != CAMERA_SOCKET_HANDOFF
        or accepted.get("actualCameraProof") != ACTUAL_CAMERA_PROOF
    ):
        reject("SIBLING_PATH_SUBSTITUTION", accepted)
    if handoff["orientationTransform"] != "none":
        reject("ORIENTATION_TRANSFORM_FORBIDDEN", handoff["orientationTransform"])
    if handoff["outputs"] != EXPECTED_OUTPUTS:
        reject("UNSAFE_OUTPUT_PATH", handoff["outputs"])
    for output_path in EXPECTED_OUTPUTS.values():
        parse_safe_relative_path(output_path, "UNSAFE_OUTPUT_PATH")
        if not (
            output_path.startswith(f"{SOURCE_ROOT}/")
            or output_path.startswith(f"{EVIDENCE_ROOT}/")
        ):
            reject("UNSAFE_OUTPUT_PATH", output_path)
    if (
        handoff["schema"]
        != "citysim.play-080.south-prelock-successor-handoff.v1"
        or handoff["taskId"] != "PLAY-080"
        or handoff["version"] != 1
        or handoff["stage"] != "prelock_successor"
        or handoff["mode"] != "zero-pixel-prelock-successor"
        or handoff["direction"] != "south"
        or handoff["branch"] != BRANCH
        or handoff["sourceStageSchema"] != SOURCE_STAGE_SCHEMA
        or handoff["missingAuthorities"] != MISSING_AUTHORITIES
        or handoff["gates"] != EXPECTED_GATES
        or handoff["activity"] != EXPECTED_ACTIVITY
        or handoff["disposition"]
        != "BLOCKED_MISSING_APPEARANCE_LOCK_AND_SOURCE_PRODUCTION_PROFILE"
    ):
        reject("SUCCESSOR_CONTRACT_MISMATCH")


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
        elif isinstance(target, list) and part.isdigit() and int(part) < len(target):
            target = target[int(part)]
        else:
            reject("INVALID_MUTATION_PATH", pointer)
    final = parts[-1]
    if isinstance(target, dict) and final in target:
        target[final] = mutation["value"]
    elif isinstance(target, list) and final.isdigit() and int(final) < len(target):
        target[int(final)] = mutation["value"]
    else:
        reject("INVALID_MUTATION_PATH", pointer)
    return candidate


def expect_rejection(
    case_id: str, expected_code: str, handoff: dict[str, Any], mutation: dict[str, Any]
) -> dict[str, str]:
    try:
        validate_handoff_identity(apply_mutation(handoff, mutation))
    except SuccessorRejected as error:
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
        "mutationPath": mutation["path"],
        "rejectionCode": expected_code,
        "result": "PASS_FAIL_CLOSED",
    }


def verify_predecessor_replay(
    before_verifier: CapturedFile, before_proof: CapturedFile
) -> tuple[dict[str, Any], dict[str, tuple[int, ...]]]:
    result = subprocess.run(
        [
            sys.executable,
            str(REPOSITORY_ROOT / HARDENED_VERIFIER["path"]),
            "--verify",
        ],
        check=False,
        capture_output=True,
        text=True,
        cwd=REPOSITORY_ROOT,
        env={
            "GIT_CONFIG_NOSYSTEM": "1",
            "LC_ALL": "C",
            "PATH": "/usr/bin:/bin",
            "PYTHONDONTWRITEBYTECODE": "1",
        },
    )
    if result.returncode != 0:
        reject(
            "HARDENED_VERIFIER_FAILED",
            {"returnCode": result.returncode, "stderr": result.stderr.strip()},
        )
    lines = [line for line in result.stdout.splitlines() if line.strip()]
    if not lines:
        reject("HARDENED_VERIFIER_MALFORMED_OUTPUT")
    replay = load_json_bytes(lines[-1].encode("utf-8"), "hardened verifier stdout")
    if (
        replay.get("result") != "PASS"
        or replay.get("action") != "VERIFIED_READ_ONLY"
        or replay.get("reportWritten") is not False
        or replay.get("adversarialCases") != 14
        or replay.get("outputSha256") != HARDENED_PROOF["sha256"]
    ):
        reject("HARDENED_VERIFIER_RESULT_MISMATCH", replay)
    after_verifier = capture_repo_file(HARDENED_VERIFIER["path"])
    after_proof = capture_repo_file(HARDENED_PROOF["path"])
    if (
        before_verifier != after_verifier
        or before_proof != after_proof
    ):
        reject("HARDENED_REPLAY_INPUT_REPLACED")
    return (
        {
            "action": replay["action"],
            "adversarialCases": replay["adversarialCases"],
            "outputSha256": replay["outputSha256"],
            "reportWritten": replay["reportWritten"],
            "result": replay["result"],
        },
        {
            "hardenedVerifierAfter": after_verifier.identity,
            "hardenedProofAfter": after_proof.identity,
        },
    )


def validate_bound_files(
    handoff: dict[str, Any],
) -> tuple[dict[str, Any], dict[str, tuple[int, ...]]]:
    identities: dict[str, tuple[int, ...]] = {}
    loaded: dict[str, dict[str, Any]] = {}
    bindings: list[dict[str, str]] = []
    captures: dict[str, CapturedFile] = {}
    for binding in BASE_BINDINGS:
        captured = capture_repo_file(binding["path"])
        actual_sha = sha256_bytes(captured.raw)
        if actual_sha != binding["sha256"]:
            reject(
                "BOUND_FILE_HASH_MISMATCH",
                {
                    "role": binding["role"],
                    "expected": binding["sha256"],
                    "actual": actual_sha,
                },
            )
        captures[binding["role"]] = captured
        identities[binding["role"]] = captured.identity
        if binding["role"] not in {
            "claim",
            "hardenedSemanticReplayVerifier",
            "acceptedSouthScene",
            "acceptedSouthMaterials",
            "directionBridgeV06",
        }:
            loaded[binding["role"]] = load_json_bytes(
                captured.raw, binding["path"]
            )
        bindings.append(
            {
                "blobOid": binding["blobOid"],
                "path": binding["path"],
                "role": binding["role"],
                "sha256": binding["sha256"],
            }
        )

    runner = loaded["southPrelockRunner"]
    if (
        runner.get("state") != "awaiting_appearance_lock"
        or runner.get("sourceReady") is not False
        or runner.get("productionSelected") is not False
        or runner.get("appearanceLock") != MISSING_AUTHORITIES["appearanceLock"]
        or runner.get("sourceProductionProfile")
        != MISSING_AUTHORITIES["sourceProductionProfile"]
        or runner.get("postLockProductionAuthority")
        != MISSING_AUTHORITIES["postLockProductionAuthority"]
    ):
        reject("RUNNER_MISSING_AUTHORITY_GATE_MISMATCH")
    if (
        runner["acceptedPredesign"]["scene"] != {
            "path": SCENE["path"],
            "sha256": SCENE["sha256"],
        }
        or runner["acceptedPredesign"]["materials"] != {
            "path": MATERIALS["path"],
            "sha256": MATERIALS["sha256"],
        }
    ):
        reject("RUNNER_PREDESIGN_BINDING_MISMATCH")
    bridge = runner["coordinateBridge"]
    if (
        bridge.get("state") != EXPECTED_BRIDGE["state"]
        or bridge.get("acceptedCandidateCommit")
        != EXPECTED_BRIDGE["acceptedCandidateCommit"]
        or bridge.get("mappingContractPath") != BRIDGE_MAPPING["path"]
        or bridge.get("mappingContractSha256") != BRIDGE_MAPPING["sha256"]
        or bridge.get("formula") != EXPECTED_BRIDGE["formula"]
        or bridge.get("matrixRows") != EXPECTED_BRIDGE["matrixRows"]
        or bridge.get("sourceOrder") != EXPECTED_BRIDGE["sourceOrder"]
        or bridge.get("citysimToBlenderAxisOrder") != EXPECTED_BRIDGE["axisOrder"]
        or bridge.get("citysimToBlenderAxisSigns") != EXPECTED_BRIDGE["axisSigns"]
        or bridge.get("canonicalCitySimSouthSocket")
        != EXPECTED_CAMERA_SOCKET["canonicalCitySimSouthSocket"]
        or bridge.get("blenderNativeDirectionalSocket")
        != EXPECTED_CAMERA_SOCKET["blenderNativeSouthSocket"]
        or bridge.get("sourceSocketPixels")
        != EXPECTED_CAMERA_SOCKET["sourceSouthSocketPixels"]
    ):
        reject("RUNNER_BRIDGE_BINDING_MISMATCH")
    registration = runner["invariants"]["registration"]
    if (
        registration["canonicalCitySimFrontage"]["direction"] != "south"
        or registration["canonicalCitySimFrontage"]["socket"]
        != EXPECTED_CAMERA_SOCKET["canonicalCitySimSouthSocket"]
        or registration["blenderNativeFrontage"]["socket"]
        != EXPECTED_CAMERA_SOCKET["blenderNativeSouthSocket"]
        or registration["sourceProjectionObservation"]["socketPixels"]
        != EXPECTED_CAMERA_SOCKET["sourceSouthSocketPixels"]
    ):
        reject("RUNNER_SOCKET_BINDING_MISMATCH")

    camera_handoff = loaded["cameraSocketHandoff"]["cameraAndSocket"]
    for key, value in EXPECTED_CAMERA_SOCKET.items():
        if camera_handoff.get(key) != value:
            reject("CAMERA_SOCKET_PROOF_MISMATCH", key)
    if (
        camera_handoff.get("result") != "PASS"
        or camera_handoff.get("renderInvocations") != 0
        or camera_handoff.get("blenderRenderApiCalls") != 0
        or camera_handoff.get("pixelFiles") != 0
    ):
        reject("CAMERA_SOCKET_ZERO_PIXEL_MISMATCH")

    actual_camera = loaded["actualCameraProof"]
    if actual_camera.get("result") != "PASS":
        reject("ACTUAL_CAMERA_PROOF_MISMATCH")

    source_schema = loaded["sourceStageSchemaV2"]
    if (
        source_schema.get("$id") != SOURCE_STAGE_SCHEMA["id"]
        or source_schema.get("$schema") != SOURCE_STAGE_SCHEMA["draft"]
        or source_schema.get("type") != "object"
    ):
        reject("SOURCE_STAGE_SCHEMA_MISMATCH")

    predecessor_result, predecessor_identities = verify_predecessor_replay(
        captures["hardenedSemanticReplayVerifier"],
        captures["hardenedSemanticReplayProof"],
    )
    identities.update(predecessor_identities)
    return (
        {
            "bindings": bindings,
            "cameraSocket": EXPECTED_CAMERA_SOCKET,
            "missingAuthorityGate": {
                "appearanceLockMissing": True,
                "dccAuthorized": False,
                "pixelProductionAuthorized": False,
                "processA": "not_run",
                "processB": "not_run",
                "processC": "not_run",
                "sourceProductionProfileMissing": True,
                "sourceReady": False,
            },
            "predecessorReplayVerification": predecessor_result,
            "sourceStageSchema": SOURCE_STAGE_SCHEMA,
        },
        identities,
    )


def validate_once(
    handoff_raw: bytes,
) -> tuple[dict[str, Any], dict[str, tuple[int, ...]]]:
    handoff = load_json_bytes(handoff_raw, HANDOFF_PATH)
    validate_handoff_identity(handoff)
    git_authorities = validate_git_authorities()
    bound, identities = validate_bound_files(handoff)

    cases = handoff["adversarialCases"]
    if not isinstance(cases, list) or len(cases) != len(EXPECTED_CASES):
        reject("ADVERSARIAL_CASE_SET_MISMATCH")
    case_results: list[dict[str, str]] = []
    seen: set[str] = set()
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
        expected_code, expected_path = EXPECTED_CASES[case_id]
        if (
            case["expectedRejection"] != expected_code
            or case["mutation"].get("path") != expected_path
        ):
            reject("ADVERSARIAL_CASE_CONTRACT_MISMATCH", case_id)
        case_results.append(
            expect_rejection(
                case_id, expected_code, handoff, case["mutation"]
            )
        )
    if seen != set(EXPECTED_CASES):
        reject("ADVERSARIAL_CASE_SET_MISMATCH", sorted(seen))

    return (
        {
            "adversarialCases": case_results,
            "boundAuthorities": bound,
            "gitAuthorities": git_authorities,
            "outputControls": {
                "committedProofMode": "read-only-verify",
                "handoffPath": HANDOFF_PATH,
                "inputCapture": "parent-descriptor-openat-nofollow-with-restat",
                "outputCreation": "parent-descriptor-openat-nofollow-exclusive",
                "proofPath": PROOF_PATH,
            },
            "result": "PASS",
        },
        identities,
    )


def build_report() -> bytes:
    first_handoff = capture_repo_file(HANDOFF_PATH)
    first_validator = capture_repo_file(VALIDATOR_PATH)
    first, first_identities = validate_once(first_handoff.raw)
    first_identities["successorHandoff"] = first_handoff.identity
    first_identities["successorValidator"] = first_validator.identity

    second_handoff = capture_repo_file(HANDOFF_PATH)
    second_validator = capture_repo_file(VALIDATOR_PATH)
    second, second_identities = validate_once(second_handoff.raw)
    second_identities["successorHandoff"] = second_handoff.identity
    second_identities["successorValidator"] = second_validator.identity

    first_bytes = canonical_bytes(first)
    second_bytes = canonical_bytes(second)
    first_sha = sha256_bytes(first_bytes)
    second_sha = sha256_bytes(second_bytes)
    if (
        first_handoff != second_handoff
        or first_validator != second_validator
        or first_identities != second_identities
    ):
        reject("INPUT_REPLACED_BETWEEN_REPLAYS")
    if first_bytes != second_bytes:
        reject(
            "NONDETERMINISTIC_REPLAY",
            {"firstSha256": first_sha, "secondSha256": second_sha},
        )

    report = {
        "activity": EXPECTED_ACTIVITY,
        "direction": "south",
        "gates": EXPECTED_GATES,
        "handoff": {
            "path": HANDOFF_PATH,
            "sha256": sha256_bytes(first_handoff.raw),
        },
        "mode": "zero-pixel-prelock-successor-validation",
        "publishedMaster": PUBLISHED_MASTER_RECORD,
        "replay": {
            "identical": True,
            "payloadSha256": [first_sha, second_sha],
            "runs": 2,
            "stableFileIdentityAcrossRuns": True,
        },
        "result": "PASS_PRELOCK_BLOCKED",
        "schema": "citysim.play-080.south-prelock-successor-validation.v1",
        "taskId": "PLAY-080",
        "validation": first,
        "validator": {
            "path": VALIDATOR_PATH,
            "sha256": sha256_bytes(first_validator.raw),
        },
    }
    return canonical_bytes(report)


def require_cli_paths(handoff_path: str, proof_path: str) -> None:
    if handoff_path != HANDOFF_PATH:
        reject("HANDOFF_PATH_MISMATCH", handoff_path)
    if proof_path != PROOF_PATH:
        reject("UNSAFE_OUTPUT_PATH", proof_path)


def main() -> int:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--dry-run", action="store_true")
    mode.add_argument("--verify", action="store_true")
    mode.add_argument("--write", action="store_true")
    parser.add_argument("--handoff", default=HANDOFF_PATH)
    parser.add_argument("--proof", default=PROOF_PATH)
    args = parser.parse_args()

    try:
        require_cli_paths(args.handoff, args.proof)
        report = build_report()
        report_sha = sha256_bytes(report)
        if args.write:
            write_exclusive_proof(report)
            action = "WROTE_EXCLUSIVE"
            report_written = True
        elif args.verify:
            committed = capture_repo_file(PROOF_PATH)
            if committed.raw != report:
                reject(
                    "COMMITTED_PROOF_MISMATCH",
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
                    "adversarialCases": 9,
                    "proofPath": PROOF_PATH,
                    "proofSha256": report_sha,
                    "replayIdentical": True,
                    "reportWritten": report_written,
                    "result": "PASS_PRELOCK_BLOCKED",
                    "sourceReady": False,
                },
                sort_keys=True,
            )
        )
        return 0
    except SuccessorRejected as error:
        print(
            json.dumps(
                {
                    "code": error.code,
                    "details": error.details,
                    "reportWritten": False,
                    "result": "REJECTED",
                    "sourceReady": False,
                },
                sort_keys=True,
            )
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
