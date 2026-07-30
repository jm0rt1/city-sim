#!/usr/bin/env python3
"""Validate the PLAY-080 South zero-pixel post-raw fan-out preparation."""

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
from typing import Any, Callable


THIS_DIR = Path(__file__).resolve().parent
REPOSITORY_ROOT = THIS_DIR.parents[6]
SOURCE_ROOT = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-080/"
    "industrial-l04-south-source-v01/"
)
EVIDENCE_ROOT = (
    "docs/production/evidence/PLAY-080/"
    "industrial-l04-south-source-v01/"
)
MODEL_ROOT = f"{SOURCE_ROOT}post-raw-validation-fanout-v01/"
FUTURE_SOURCE_ROOT = f"{SOURCE_ROOT}outputs/post-raw-validation-fanout-v01/"
FUTURE_EVIDENCE_ROOT = f"{EVIDENCE_ROOT}post-raw-validation-fanout-v01/"
CONTRACT_PATH = f"{MODEL_ROOT}CONTRACT.json"
VALIDATOR_PATH = f"{MODEL_ROOT}validate_post_raw_fanout_v01.py"
TEST_PATH = f"{MODEL_ROOT}test_validate_post_raw_fanout_v01.py"
PROOF_PATH = f"{EVIDENCE_ROOT}POST-RAW-VALIDATION-FANOUT-V01-PROOF.json"
PACKET_PATH = f"{EVIDENCE_ROOT}FUTURE-SOURCE-STAGE-V2-HANDOFF.json"
BRANCH = "codex/citysim-world-art-south"
INTEGRATION_AUTHORITY = "5d86e804be679c765c2465c60ceaee72f3702c48"
INTEGRATION_TREE = "a1784f69bba2c7352093502fc4700140c4887171"

CLAIM = {
    "authorityCommit": INTEGRATION_AUTHORITY,
    "blobOid": "5b16e18a8a646d24133c58fcd5275b9f49516abd",
    "path": "docs/production/claims/PLAY-080.world-art-south.md",
    "sha256": "5e07bef53399485140a710b6297825c5276cb48f61a6e15032eb1c358d8bcde6",
}
FROZEN_INPUTS = {
    "bridge": {
        "blobOid": "2b82ae30e5468cd79dee29ef78ab8c41a20debcb",
        "path": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
            "industrial-l04-direction-bridge-v06/MAPPING-CONTRACT.json"
        ),
        "sha256": "5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7",
    },
    "canonicalDecoder": {
        "blobOid": "dfc7c60c2e970084d8a08f4914eae60683acc42e",
        "path": "Native/CitySimNative/WorldArt/Shared/canonical_rgba_v1.swift",
        "sha256": "2be2b57d0c9bb73e8a4438c69aa4230eba08c4b87937fae4d4e048244b9beaab",
    },
    "materials": {
        "blobOid": "3a11708434c1df4e85e699b84bcf7a88fbf439e9",
        "path": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-080/"
            "industrial-l04-south-predesign-v01.materials.json"
        ),
        "sha256": "624b34f10354c79e0ced914ed55cf4dcb05468997d4efb679f881477984244fb",
    },
    "predecessorHandoff": {
        "blobOid": "3602a1713b3b44196bc43fec665aadd83b7d315b",
        "path": f"{SOURCE_ROOT}prelock-successor-v01.json",
        "sha256": "487fc9edf01b94d74d781c18d0178d676ae75c7f1eed85de5bb845abaf30ace9",
    },
    "predecessorProof": {
        "blobOid": "706ec64f4284cac8b2d538651372aeb792ac14d7",
        "path": f"{EVIDENCE_ROOT}PRELOCK-SUCCESSOR-V01-VALIDATION.json",
        "sha256": "a578c520afcaeed2a13490e296bb08fdb2e72d5af3fdb0f336efbc6a166ff66a",
    },
    "predecessorValidator": {
        "blobOid": "b93a0d2fb3f7a5aa54c149f700a2c39d6598c4fa",
        "path": f"{SOURCE_ROOT}validate_prelock_successor_v01.py",
        "sha256": "c0ac7fb514f9a6f80bac11c8f95ca41acf0b56f2d19f0c65b106080b3b06b00f",
    },
    "runner": {
        "blobOid": "bde316b55999a03b63316e89b02cdd8443b0bc33",
        "path": f"{SOURCE_ROOT}runner-contract.json",
        "sha256": "bc74613e9fdcc5b7c378488b0a5c3b5404087fb231da2b528b719597a1df03a2",
    },
    "scene": {
        "blobOid": "d04d7630436430907caaeb4eaa9c2d04304190ad",
        "path": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-080/"
            "industrial-l04-south-predesign-v01.scene.json"
        ),
        "sha256": "e0c8dd02f261844daa3d78ba05c482acbbe9b08eac835a0f863621f48010b07d",
    },
    "semanticValidator": {
        "blobOid": "4e64b273321ed62096bfa5d6f82a9260ed0a3c10",
        "path": "Native/CitySimNative/WorldArt/Shared/validate_source_stage_handoff_v2.py",
        "sha256": "7a0613af9998a222a583a70930ce3afc5ec1902793f03201f899a2bb4129f340",
    },
    "sourceStageSchema": {
        "blobOid": "198937fd641a9e117a4e96136052ae8607025675",
        "path": (
            "docs/production/evidence/INTEGRATION/"
            "industrial-l04-source-stage-handoff-schema-v2.json"
        ),
        "sha256": "93efe9ca6d000a2d145098f722338c8e85829d6de6724c3f231a93c06eadf3d7",
    },
}
INTEGRATION_RECORD = {
    "commit": INTEGRATION_AUTHORITY,
    "runtimeHeadPolicy": "integration-authority-is-ancestor",
    "treeOid": INTEGRATION_TREE,
}
MISSING_APPEARANCE_LOCK = {
    "appearanceLockCommit": None,
    "appearanceLockSha256": None,
    "documentPath": None,
    "northProcessADecodedRgbaSha256": None,
    "northProcessASourceSha256": None,
}
MISSING_PROFILE = {"commit": None, "path": None, "sha256": None}
RELEASE_AUTHORITIES = {
    "appearanceLock": MISSING_APPEARANCE_LOCK,
    "postLockProductionAuthority": MISSING_PROFILE,
    "sourceProductionProfile": MISSING_PROFILE,
    "state": "blocked_missing_appearance_lock_and_source_production_profile",
}
ROOT_POLICY = {
    "allowedEvidencePrefix": EVIDENCE_ROOT,
    "allowedSourcePrefix": SOURCE_ROOT,
    "disjointRootsRequired": True,
    "noFollow": True,
    "noOverwrite": True,
}
GATES = {
    "admissionAuthorized": False,
    "appearanceLockPresent": False,
    "candidateReadyForIndependentReview": False,
    "consumersReleased": False,
    "dccAuthorized": False,
    "integrationAdmitted": False,
    "pixelProductionAuthorized": False,
    "postLockProductionAuthorityPresent": False,
    "productionSelected": False,
    "rendererQuarantined": False,
    "shippingAuthorized": False,
    "sourceProductionProfilePresent": False,
    "sourceReady": False,
}
ACTIVITY = {
    "assemblerInvocations": 0,
    "blenderProcessLaunches": 0,
    "blenderRenderApiCalls": 0,
    "contactSheetInvocations": 0,
    "dccProcessLaunches": 0,
    "imageGenInvocations": 0,
    "normalizerInvocations": 0,
    "pixelFiles": 0,
    "renderInvocations": 0,
    "sourcePackets": 0,
    "validationJobInvocations": 0,
}
OUTPUTS = {
    "contract": CONTRACT_PATH,
    "proof": PROOF_PATH,
    "tests": TEST_PATH,
    "validator": VALIDATOR_PATH,
}
RAW_PROCESSES = {
    process: {
        "rawPath": f"{SOURCE_ROOT}outputs/process-{process}/raw.png",
        "semanticPath": f"{SOURCE_ROOT}outputs/process-{process}/semantic.png",
        "state": "not_produced",
    }
    for process in ("A", "B", "C")
}
EXPECTED_ROOTS = {
    **{
        f"provenance-rgba-{process}": (
            f"{FUTURE_EVIDENCE_ROOT}provenance-rgba/process-{process}/"
        )
        for process in ("A", "B", "C")
    },
    "identity-join": f"{FUTURE_EVIDENCE_ROOT}identity-join/",
    **{
        f"normalization-output-{process}": (
            f"{FUTURE_SOURCE_ROOT}normalization-repeat/process-{process}/"
        )
        for process in ("A", "B", "C")
    },
    **{
        f"normalization-evidence-{process}": (
            f"{FUTURE_EVIDENCE_ROOT}normalization-repeat/process-{process}/"
        )
        for process in ("A", "B", "C")
    },
    "literal-color-output": f"{FUTURE_SOURCE_ROOT}literal-scale/color/",
    "literal-color-evidence": f"{FUTURE_EVIDENCE_ROOT}literal-scale/color/",
    "literal-grayscale-output": f"{FUTURE_SOURCE_ROOT}literal-scale/grayscale/",
    "literal-grayscale-evidence": f"{FUTURE_EVIDENCE_ROOT}literal-scale/grayscale/",
    "contact-sheet-output": (
        f"{FUTURE_EVIDENCE_ROOT}literal-scale/contact-sheet-pixels/"
    ),
    "contact-sheet-evidence": f"{FUTURE_EVIDENCE_ROOT}literal-scale/contact-sheet/",
    "assembler": f"{FUTURE_EVIDENCE_ROOT}assembler/",
}
EXPECTED_DEPENDENCIES = {
    "provenanceRgba": ["raw-A:closed", "raw-B:closed", "raw-C:closed"],
    "identityJoin": [
        "provenance-rgba-A:settled",
        "provenance-rgba-B:settled",
        "provenance-rgba-C:settled",
    ],
    "normalizationRepeat": ["identity-join:settled"],
    "literalScale": [
        "normalization-repeat-A:settled",
        "normalization-repeat-B:settled",
        "normalization-repeat-C:settled",
    ],
    "assembler": [
        "literal-color:settled",
        "literal-grayscale:settled",
        "contact-sheet:settled",
    ],
}


class FanoutRejected(RuntimeError):
    """Fail-closed validation rejection."""

    def __init__(self, code: str, details: Any = None):
        super().__init__(code)
        self.code = code
        self.details = details


@dataclass(frozen=True)
class CapturedFile:
    raw: bytes
    identity: tuple[int, int, int, int, int]


RootProbe = Callable[[str], str]


def reject(code: str, details: Any = None) -> None:
    raise FanoutRejected(code, details)


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
    value: Any, expected: set[str], label: str
) -> dict[str, Any]:
    if not isinstance(value, dict):
        reject("OBJECT_NOT_FOUND", label)
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
    return value


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


def file_identity(value: os.stat_result) -> tuple[int, int, int, int, int]:
    return (
        value.st_dev,
        value.st_ino,
        value.st_mode,
        value.st_size,
        value.st_mtime_ns,
    )


def open_parent_descriptor(
    relative_path: str, unsafe_code: str
) -> tuple[int, str]:
    pure = parse_safe_relative_path(relative_path, unsafe_code)
    flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
    descriptor = os.open(REPOSITORY_ROOT, flags)
    try:
        for component in pure.parts[:-1]:
            try:
                child = os.open(component, flags, dir_fd=descriptor)
            except OSError as error:
                reject(
                    unsafe_code,
                    {
                        "path": relative_path,
                        "component": component,
                        "errno": error.errno,
                    },
                )
            os.close(descriptor)
            descriptor = child
        return descriptor, pure.parts[-1]
    except BaseException:
        os.close(descriptor)
        raise


def capture_file(relative_path: str, code: str) -> CapturedFile:
    parent, leaf = open_parent_descriptor(relative_path, code)
    descriptor = -1
    try:
        try:
            descriptor = os.open(
                leaf, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=parent
            )
        except OSError as error:
            reject(code, {"path": relative_path, "errno": error.errno})
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode):
            reject(code, {"path": relative_path, "reason": "not-regular"})
        chunks: list[bytes] = []
        while True:
            chunk = os.read(descriptor, 1024 * 1024)
            if not chunk:
                break
            chunks.append(chunk)
        after = os.fstat(descriptor)
        visible = os.stat(leaf, dir_fd=parent, follow_symlinks=False)
        if (
            file_identity(before) != file_identity(after)
            or file_identity(after) != file_identity(visible)
        ):
            reject(code, {"path": relative_path, "reason": "replacement-race"})
        return CapturedFile(b"".join(chunks), file_identity(after))
    finally:
        if descriptor >= 0:
            os.close(descriptor)
        os.close(parent)


def inspect_future_path(relative_path: str) -> str:
    pure = parse_safe_relative_path(relative_path, "UNSAFE_OUTPUT_ROOT")
    descriptor = os.open(
        REPOSITORY_ROOT, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
    )
    try:
        for index, component in enumerate(pure.parts):
            try:
                visible = os.stat(
                    component, dir_fd=descriptor, follow_symlinks=False
                )
            except FileNotFoundError:
                return "missing"
            if stat.S_ISLNK(visible.st_mode):
                return "symlink"
            if index == len(pure.parts) - 1:
                return "exists"
            if not stat.S_ISDIR(visible.st_mode):
                return "blocked"
            try:
                child = os.open(
                    component,
                    os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW,
                    dir_fd=descriptor,
                )
            except OSError as error:
                reject(
                    "OUTPUT_ROOT_REPLACEMENT_RACE",
                    {
                        "path": relative_path,
                        "component": component,
                        "errno": error.errno,
                    },
                )
            os.close(descriptor)
            descriptor = child
        return "exists"
    finally:
        os.close(descriptor)


def git(*arguments: str, allow_failure: bool = False) -> str:
    result = subprocess.run(
        ["git", *arguments],
        cwd=REPOSITORY_ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode and not allow_failure:
        reject(
            "GIT_AUTHORITY_FAILURE",
            {"arguments": list(arguments), "stderr": result.stderr.strip()},
        )
    return result.stdout.strip()


def validate_environment() -> dict[str, Any]:
    branch = git("branch", "--show-current")
    if branch != BRANCH:
        reject("WRONG_BRANCH", {"expected": BRANCH, "actual": branch})
    if (
        subprocess.run(
            ["git", "merge-base", "--is-ancestor", INTEGRATION_AUTHORITY, "HEAD"],
            cwd=REPOSITORY_ROOT,
            capture_output=True,
            check=False,
        ).returncode
        != 0
    ):
        reject("STALE_INTEGRATION_AUTHORITY", INTEGRATION_AUTHORITY)
    tree = git("rev-parse", f"{INTEGRATION_AUTHORITY}^{{tree}}")
    if tree != INTEGRATION_TREE:
        reject(
            "STALE_INTEGRATION_TREE",
            {"expected": INTEGRATION_TREE, "actual": tree},
        )
    bindings = {"claim": CLAIM, **FROZEN_INPUTS}
    verified: list[dict[str, str]] = []
    for role, binding in bindings.items():
        captured = capture_file(binding["path"], "BOUND_INPUT_UNSAFE")
        digest = sha256_bytes(captured.raw)
        if digest != binding["sha256"]:
            reject(
                "BOUND_INPUT_HASH_MISMATCH",
                {"role": role, "expected": binding["sha256"], "actual": digest},
            )
        blob = git("rev-parse", f"{INTEGRATION_AUTHORITY}:{binding['path']}")
        if blob != binding["blobOid"]:
            reject(
                "BOUND_INPUT_BLOB_MISMATCH",
                {"role": role, "expected": binding["blobOid"], "actual": blob},
            )
        verified.append(
            {
                "role": role,
                "path": binding["path"],
                "sha256": digest,
                "blobOid": blob,
            }
        )
    runner = load_json_bytes(
        capture_file(FROZEN_INPUTS["runner"]["path"], "RUNNER_UNSAFE").raw,
        "runner",
    )
    if runner.get("appearanceLock") != MISSING_APPEARANCE_LOCK:
        reject("RUNNER_APPEARANCE_LOCK_NOT_MISSING")
    if runner.get("sourceProductionProfile") != MISSING_PROFILE:
        reject("RUNNER_SOURCE_PROFILE_NOT_MISSING")
    if runner.get("postLockProductionAuthority") != MISSING_PROFILE:
        reject("RUNNER_POST_LOCK_AUTHORITY_NOT_MISSING")
    if runner.get("sourceReady") is not False:
        reject("RUNNER_SOURCE_READY")
    predecessor = load_json_bytes(
        capture_file(
            FROZEN_INPUTS["predecessorProof"]["path"], "PREDECESSOR_UNSAFE"
        ).raw,
        "predecessor proof",
    )
    if (
        predecessor.get("result") != "PASS_PRELOCK_BLOCKED"
        or predecessor.get("gates", {}).get("sourceReady") is not False
        or any(predecessor.get("activity", {}).values())
    ):
        reject("PREDECESSOR_PROOF_MISMATCH")
    raw_inputs: list[dict[str, str]] = []
    for process, record in RAW_PROCESSES.items():
        for role in ("rawPath", "semanticPath"):
            path = record[role]
            state = inspect_future_path(path)
            if state != "missing":
                reject(
                    "PRELOCK_RAW_PIXEL_PREEXISTS",
                    {
                        "process": process,
                        "role": role,
                        "path": path,
                        "state": state,
                    },
                )
            raw_inputs.append(
                {
                    "process": process,
                    "role": role,
                    "path": path,
                    "state": state,
                }
            )
    return {
        "branch": branch,
        "runtimeHeadPolicy": "integration-authority-is-ancestor",
        "bindings": verified,
        "rawInputs": raw_inputs,
    }


def collect_roots(payload: dict[str, Any]) -> dict[str, str]:
    fanout = payload["fanout"]
    roots: dict[str, str] = {}
    for process in ("A", "B", "C"):
        roots[f"provenance-rgba-{process}"] = fanout["provenanceRgba"][
            "jobs"
        ][process]["evidenceRoot"]
    roots["identity-join"] = fanout["identityJoin"]["evidenceRoot"]
    for process in ("A", "B", "C"):
        job = fanout["normalizationRepeat"]["jobs"][process]
        roots[f"normalization-output-{process}"] = job["outputRoot"]
        roots[f"normalization-evidence-{process}"] = job["evidenceRoot"]
    literal = fanout["literalScale"]["jobs"]
    roots["literal-color-output"] = literal["color"]["outputRoot"]
    roots["literal-color-evidence"] = literal["color"]["evidenceRoot"]
    roots["literal-grayscale-output"] = literal["grayscale"]["outputRoot"]
    roots["literal-grayscale-evidence"] = literal["grayscale"]["evidenceRoot"]
    roots["contact-sheet-output"] = literal["contactSheet"]["outputRoot"]
    roots["contact-sheet-evidence"] = literal["contactSheet"]["evidenceRoot"]
    roots["assembler"] = fanout["assembler"]["evidenceRoot"]
    return roots


def validate_consumers_blocked(payload: dict[str, Any]) -> None:
    fanout = payload["fanout"]
    require_exact_keys(
        fanout,
        {
            "assembler",
            "identityJoin",
            "literalScale",
            "normalizationRepeat",
            "provenanceRgba",
        },
        "fanout",
    )
    for stage in ("provenanceRgba", "normalizationRepeat"):
        require_exact_keys(
            fanout[stage],
            {"dependsOn", "jobs", "released"},
            f"fanout.{stage}",
        )
        require_exact_keys(
            fanout[stage]["jobs"], {"A", "B", "C"}, f"fanout.{stage}.jobs"
        )
    require_exact_keys(
        fanout["identityJoin"],
        {"dependsOn", "evidenceRoot", "invocations", "released", "state"},
        "fanout.identityJoin",
    )
    require_exact_keys(
        fanout["literalScale"],
        {"dependsOn", "jobs", "released"},
        "fanout.literalScale",
    )
    require_exact_keys(
        fanout["literalScale"]["jobs"],
        {"color", "contactSheet", "grayscale"},
        "fanout.literalScale.jobs",
    )
    require_exact_keys(
        fanout["assembler"],
        {
            "dependsOn",
            "evidenceRoot",
            "invocations",
            "packetPath",
            "singleWriter",
            "singleWriterId",
            "state",
        },
        "fanout.assembler",
    )
    consumers: list[tuple[str, dict[str, Any]]] = []
    for process in ("A", "B", "C"):
        consumers.append(
            (
                f"provenance-rgba-{process}",
                fanout["provenanceRgba"]["jobs"][process],
            )
        )
        consumers.append(
            (
                f"normalization-repeat-{process}",
                fanout["normalizationRepeat"]["jobs"][process],
            )
        )
    for name in ("color", "grayscale", "contactSheet"):
        consumers.append(
            (f"literal-{name}", fanout["literalScale"]["jobs"][name])
        )
    consumers.extend(
        [
            ("identity-join", fanout["identityJoin"]),
            ("assembler", fanout["assembler"]),
        ]
    )
    early = [
        {
            "consumer": name,
            "state": value.get("state"),
            "invocations": value.get("invocations"),
        }
        for name, value in consumers
        if value.get("state") != "not_run" or value.get("invocations") != 0
    ]
    if early:
        reject("EARLY_CONSUMER", early)
    for stage in (
        fanout["provenanceRgba"],
        fanout["identityJoin"],
        fanout["normalizationRepeat"],
        fanout["literalScale"],
    ):
        if stage.get("released") is not False:
            reject("EARLY_CONSUMER_RELEASE", stage)
    source_state = payload["sourceState"]
    if source_state.get("rawFanoutSettled") is not False:
        reject("RAW_FANOUT_STATE_MISMATCH")
    if source_state.get("rawProcesses") != RAW_PROCESSES:
        reject("RAW_PROCESS_STATE_MISMATCH")


def validate_dependencies(fanout: dict[str, Any]) -> None:
    for stage, expected in EXPECTED_DEPENDENCIES.items():
        if fanout[stage].get("dependsOn") != expected:
            reject(
                "DEPENDENCY_DAG_MISMATCH",
                {
                    "stage": stage,
                    "expected": expected,
                    "actual": fanout[stage].get("dependsOn"),
                },
            )
    assembler = fanout["assembler"]
    if (
        assembler.get("singleWriter") is not True
        or assembler.get("singleWriterId")
        != "play-080-south-source-assembler-v01"
        or assembler.get("packetPath") != PACKET_PATH
    ):
        reject("SINGLE_ASSEMBLER_MISMATCH")


def classify_root(path: str) -> str:
    pure = parse_safe_relative_path(path, "UNSAFE_OUTPUT_ROOT")
    text = pure.as_posix() + ("/" if path.endswith("/") else "")
    if "/PLAY-079/" in text or "/PLAY-081/" in text or "/PLAY-027/" in text:
        reject("SIBLING_PATH_SUBSTITUTION", path)
    if text.startswith(SOURCE_ROOT):
        return "source"
    if text.startswith(EVIDENCE_ROOT):
        return "evidence"
    reject("ROOT_OWNERSHIP_VIOLATION", path)


def validate_roots(payload: dict[str, Any], root_probe: RootProbe) -> list[dict[str, str]]:
    roots = collect_roots(payload)
    parsed: list[tuple[str, PurePosixPath]] = []
    for role, path in roots.items():
        classify_root(path)
        parsed.append((role, parse_safe_relative_path(path, "UNSAFE_OUTPUT_ROOT")))
    for index, (left_role, left) in enumerate(parsed):
        for right_role, right in parsed[index + 1 :]:
            if left == right or left in right.parents or right in left.parents:
                reject(
                    "ROOT_OVERLAP",
                    {
                        "left": left_role,
                        "leftPath": left.as_posix(),
                        "right": right_role,
                        "rightPath": right.as_posix(),
                    },
                )
    for role, expected in EXPECTED_ROOTS.items():
        if roots.get(role) != expected:
            reject(
                "ROOT_BINDING_MISMATCH",
                {"role": role, "expected": expected, "actual": roots.get(role)},
            )
    checked: list[dict[str, str]] = []
    for role in sorted(roots):
        state = root_probe(roots[role])
        if state == "symlink":
            reject("SYMLINK_OUTPUT_ROOT", {"role": role, "path": roots[role]})
        if state != "missing":
            reject(
                "OUTPUT_ROOT_PREEXISTS",
                {"role": role, "path": roots[role], "state": state},
            )
        checked.append({"role": role, "path": roots[role], "state": state})
    classify_root(PACKET_PATH)
    packet_state = root_probe(PACKET_PATH)
    if packet_state == "symlink":
        reject("SYMLINK_OUTPUT_ROOT", {"role": "packet", "path": PACKET_PATH})
    if packet_state != "missing":
        reject(
            "OUTPUT_ROOT_PREEXISTS",
            {"role": "packet", "path": PACKET_PATH, "state": packet_state},
        )
    checked.append({"role": "packet", "path": PACKET_PATH, "state": packet_state})
    return checked


def validate_payload(
    payload: dict[str, Any],
    *,
    root_probe: RootProbe = inspect_future_path,
    check_environment: bool = True,
) -> dict[str, Any]:
    require_exact_keys(
        payload,
        {
            "activity",
            "branch",
            "claim",
            "direction",
            "disposition",
            "fanout",
            "frozenInputs",
            "gates",
            "integrationAuthority",
            "mode",
            "orientationTransform",
            "outputs",
            "releaseAuthorities",
            "rootPolicy",
            "schema",
            "sourceState",
            "stage",
            "taskId",
        },
        "contract",
    )
    if payload.get("schema") != "citysim.play-080.south-post-raw-validation-fanout.v1":
        reject("SCHEMA_MISMATCH")
    if payload.get("taskId") != "PLAY-080":
        reject("TASK_MISMATCH")
    if payload.get("direction") != "south":
        reject("DIRECTION_MISMATCH")
    if payload.get("branch") != BRANCH:
        reject("BRANCH_MISMATCH")
    if payload.get("integrationAuthority") != INTEGRATION_RECORD:
        reject("STALE_INTEGRATION_AUTHORITY")
    if payload.get("claim") != CLAIM:
        reject("WRONG_CLAIM")
    if payload.get("frozenInputs") != FROZEN_INPUTS:
        reject("FROZEN_INPUT_MISMATCH")
    release = payload.get("releaseAuthorities", {})
    if release.get("appearanceLock") != MISSING_APPEARANCE_LOCK:
        reject("APPEARANCE_LOCK_GATE_MISMATCH")
    if release.get("sourceProductionProfile") != MISSING_PROFILE:
        reject("SOURCE_PRODUCTION_PROFILE_GATE_MISMATCH")
    if release.get("postLockProductionAuthority") != MISSING_PROFILE:
        reject("POST_LOCK_AUTHORITY_GATE_MISMATCH")
    if release != RELEASE_AUTHORITIES:
        reject("RELEASE_AUTHORITY_STATE_MISMATCH")
    if payload.get("orientationTransform") != "none":
        reject("ORIENTATION_TRANSFORM_FORBIDDEN")
    if payload.get("rootPolicy") != ROOT_POLICY:
        if payload.get("rootPolicy", {}).get("noOverwrite") is not True:
            reject("OVERWRITE_POLICY_MISMATCH")
        if payload.get("rootPolicy", {}).get("noFollow") is not True:
            reject("NOFOLLOW_POLICY_MISMATCH")
        reject("ROOT_POLICY_MISMATCH")
    if payload.get("gates") != GATES:
        reject("GATE_STATE_MISMATCH")
    if payload.get("activity") != ACTIVITY:
        reject("ZERO_ACTIVITY_MISMATCH")
    if payload.get("outputs") != OUTPUTS:
        reject("OUTPUT_BINDING_MISMATCH")
    if payload.get("mode") != "zero-pixel-post-raw-validation-fanout-prep":
        reject("MODE_MISMATCH")
    if payload.get("stage") != "prelock_post_raw_validation_fanout_prep":
        reject("STAGE_MISMATCH")
    if (
        payload.get("disposition")
        != "BLOCKED_MISSING_APPEARANCE_LOCK_AND_SOURCE_PRODUCTION_PROFILE"
    ):
        reject("DISPOSITION_MISMATCH")
    if not isinstance(payload.get("fanout"), dict):
        reject("FANOUT_MISSING")
    validate_consumers_blocked(payload)
    validate_dependencies(payload["fanout"])
    checked_roots = validate_roots(payload, root_probe)
    environment = validate_environment() if check_environment else None
    return {
        "checkedRoots": checked_roots,
        "environment": environment,
        "dependencyGraph": [
            "raw-A/B/C:closed",
            "provenance-rgba-A/B/C:settled",
            "identity-join:settled",
            "normalization-repeat-A/B/C:settled",
            "literal-color/grayscale/contact-sheet:settled",
            "single-assembler",
        ],
    }


def pointer_set(payload: dict[str, Any], pointer: str, value: Any) -> None:
    parts = pointer.lstrip("/").split("/")
    target: Any = payload
    for part in parts[:-1]:
        target = target[part]
    target[parts[-1]] = value


def run_adversaries(payload: dict[str, Any]) -> list[dict[str, str]]:
    first_root = EXPECTED_ROOTS["provenance-rgba-A"]
    cases: list[tuple[str, str, str | None, Any, RootProbe | None]] = [
        (
            "stale-integration-master",
            "STALE_INTEGRATION_AUTHORITY",
            "/integrationAuthority/commit",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            None,
        ),
        (
            "wrong-claim",
            "WRONG_CLAIM",
            "/claim/sha256",
            "a" * 64,
            None,
        ),
        (
            "partial-appearance-lock",
            "APPEARANCE_LOCK_GATE_MISMATCH",
            "/releaseAuthorities/appearanceLock/documentPath",
            "docs/production/evidence/INTEGRATION/unpublished-lock.json",
            None,
        ),
        (
            "partial-source-production-profile",
            "SOURCE_PRODUCTION_PROFILE_GATE_MISMATCH",
            "/releaseAuthorities/sourceProductionProfile/path",
            "docs/production/evidence/INTEGRATION/unpublished-profile.json",
            None,
        ),
        (
            "race-provenance-before-raw-close",
            "EARLY_CONSUMER",
            "/fanout/provenanceRgba/jobs/A/state",
            "running",
            None,
        ),
        (
            "overlapping-process-roots",
            "ROOT_OVERLAP",
            "/fanout/provenanceRgba/jobs/B/evidenceRoot",
            first_root,
            None,
        ),
        (
            "overwrite-enabled",
            "OVERWRITE_POLICY_MISMATCH",
            "/rootPolicy/noOverwrite",
            False,
            None,
        ),
        (
            "symlink-output-root",
            "SYMLINK_OUTPUT_ROOT",
            None,
            None,
            lambda path: "symlink" if path == first_root else "missing",
        ),
        (
            "sibling-path-substitution",
            "SIBLING_PATH_SUBSTITUTION",
            "/fanout/provenanceRgba/jobs/A/evidenceRoot",
            (
                "docs/production/evidence/PLAY-079/"
                "industrial-l04-east-source-v01/post-raw/process-A/"
            ),
            None,
        ),
        (
            "orientation-transform",
            "ORIENTATION_TRANSFORM_FORBIDDEN",
            "/orientationTransform",
            "rotate-180",
            None,
        ),
        (
            "unsafe-traversal-root",
            "UNSAFE_OUTPUT_ROOT",
            "/fanout/provenanceRgba/jobs/A/evidenceRoot",
            f"{EVIDENCE_ROOT}../../../../Rendering/",
            None,
        ),
        (
            "unsafe-absolute-root",
            "UNSAFE_OUTPUT_ROOT",
            "/fanout/provenanceRgba/jobs/A/evidenceRoot",
            "/tmp/play-080-escape/",
            None,
        ),
        (
            "preexisting-output-root",
            "OUTPUT_ROOT_PREEXISTS",
            None,
            None,
            lambda path: "exists" if path == first_root else "missing",
        ),
        (
            "early-identity-consumer",
            "EARLY_CONSUMER",
            "/fanout/identityJoin/invocations",
            1,
            None,
        ),
        (
            "early-literal-consumer",
            "EARLY_CONSUMER",
            "/fanout/literalScale/jobs/color/invocations",
            1,
            None,
        ),
        (
            "early-assembler",
            "EARLY_CONSUMER",
            "/fanout/assembler/invocations",
            1,
            None,
        ),
    ]
    results: list[dict[str, str]] = []
    for case_id, expected, pointer, value, probe in cases:
        candidate = copy.deepcopy(payload)
        if pointer is not None:
            pointer_set(candidate, pointer, value)
        try:
            validate_payload(
                candidate,
                root_probe=probe or (lambda _path: "missing"),
                check_environment=False,
            )
        except FanoutRejected as error:
            if error.code != expected:
                reject(
                    "ADVERSARY_WRONG_REJECTION",
                    {
                        "id": case_id,
                        "expected": expected,
                        "actual": error.code,
                    },
                )
            results.append(
                {
                    "id": case_id,
                    "rejectionCode": error.code,
                    "result": "PASS_FAIL_CLOSED",
                }
            )
        else:
            reject("ADVERSARY_FAILED_OPEN", case_id)
    return results


def build_report(
    payload: dict[str, Any],
    contract_capture: CapturedFile,
    validation: dict[str, Any],
) -> dict[str, Any]:
    adversaries = run_adversaries(payload)
    implementation = {}
    for role, relative_path in (
        ("contract", CONTRACT_PATH),
        ("validator", VALIDATOR_PATH),
        ("tests", TEST_PATH),
    ):
        captured = capture_file(relative_path, "IMPLEMENTATION_INPUT_UNSAFE")
        implementation[role] = {
            "path": relative_path,
            "sha256": sha256_bytes(captured.raw),
        }
    return {
        "activity": ACTIVITY,
        "branch": BRANCH,
        "dependencyGraph": validation["dependencyGraph"],
        "direction": "south",
        "disposition": (
            "BLOCKED_MISSING_APPEARANCE_LOCK_AND_SOURCE_PRODUCTION_PROFILE"
        ),
        "gates": GATES,
        "implementation": implementation,
        "integrationAuthority": INTEGRATION_RECORD,
        "releaseAuthorities": RELEASE_AUTHORITIES,
        "result": "PASS_PRELOCK_BLOCKED",
        "rootIsolation": {
            "checked": validation["checkedRoots"],
            "disjoint": True,
            "noFollow": True,
            "noOverwrite": True,
        },
        "schema": "citysim.play-080.south-post-raw-validation-fanout-proof.v1",
        "sourceReady": False,
        "taskId": "PLAY-080",
        "validation": {
            "adversarialCases": adversaries,
            "environment": validation["environment"],
            "failClosedCases": len(adversaries),
            "status": "PASS",
        },
    }


def deterministic_report() -> dict[str, Any]:
    first_capture = capture_file(CONTRACT_PATH, "CONTRACT_INPUT_UNSAFE")
    first_payload = load_json_bytes(first_capture.raw, CONTRACT_PATH)
    first_validation = validate_payload(first_payload)
    first_report = build_report(first_payload, first_capture, first_validation)

    second_capture = capture_file(CONTRACT_PATH, "CONTRACT_INPUT_UNSAFE")
    second_payload = load_json_bytes(second_capture.raw, CONTRACT_PATH)
    second_validation = validate_payload(second_payload)
    second_report = build_report(second_payload, second_capture, second_validation)
    first_bytes = canonical_bytes(first_report)
    second_bytes = canonical_bytes(second_report)
    if (
        first_capture.identity != second_capture.identity
        or first_capture.raw != second_capture.raw
        or first_bytes != second_bytes
    ):
        reject("REPLAY_NOT_IDENTICAL")
    report = copy.deepcopy(first_report)
    report["replay"] = {
        "byteIdentical": True,
        "payloadSha256": [sha256_bytes(first_bytes), sha256_bytes(second_bytes)],
        "runs": 2,
        "stableContractIdentity": True,
    }
    return report


def write_exclusive(relative_path: str, raw: bytes) -> None:
    parent, leaf = open_parent_descriptor(relative_path, "UNSAFE_PROOF_PATH")
    descriptor = -1
    try:
        try:
            descriptor = os.open(
                leaf,
                os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                0o644,
                dir_fd=parent,
            )
        except FileExistsError:
            reject("OUTPUT_EXISTS", relative_path)
        except OSError as error:
            if error.errno in {errno.ELOOP, errno.ENOTDIR}:
                reject("UNSAFE_PROOF_PATH", relative_path)
            raise
        offset = 0
        while offset < len(raw):
            offset += os.write(descriptor, raw[offset:])
        os.fsync(descriptor)
    finally:
        if descriptor >= 0:
            os.close(descriptor)
        os.close(parent)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--dry-run", action="store_true")
    mode.add_argument("--write", action="store_true")
    mode.add_argument("--verify", action="store_true")
    parser.add_argument("--contract", default=CONTRACT_PATH)
    parser.add_argument("--proof", default=PROOF_PATH)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        if args.contract != CONTRACT_PATH:
            reject("CONTRACT_PATH_MISMATCH", args.contract)
        if args.proof != PROOF_PATH:
            reject("PROOF_PATH_MISMATCH", args.proof)
        report = deterministic_report()
        raw = canonical_bytes(report)
        digest = sha256_bytes(raw)
        if args.write:
            write_exclusive(PROOF_PATH, raw)
            action = "WROTE_EXCLUSIVE"
            report_written = True
        elif args.verify:
            proof = capture_file(PROOF_PATH, "PROOF_INPUT_UNSAFE")
            if proof.raw != raw:
                reject(
                    "PROOF_CONTENT_MISMATCH",
                    {
                        "expected": digest,
                        "actual": sha256_bytes(proof.raw),
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
                    "failClosedCases": len(
                        report["validation"]["adversarialCases"]
                    ),
                    "pixelFiles": report["activity"]["pixelFiles"],
                    "proofPath": PROOF_PATH,
                    "proofSha256": digest,
                    "replayIdentical": report["replay"]["byteIdentical"],
                    "reportWritten": report_written,
                    "result": report["result"],
                    "sourceReady": report["sourceReady"],
                },
                sort_keys=True,
            )
        )
        return 0
    except FanoutRejected as error:
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
