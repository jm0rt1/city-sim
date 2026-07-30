#!/usr/bin/env python3
"""Consume an Integration schedule without directly starting any DCC child."""

from __future__ import annotations

import argparse
import copy
from dataclasses import dataclass
import errno
import hashlib
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import stat
import subprocess
import sys
from typing import Any


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
MODEL_ROOT = f"{SOURCE_ROOT}schedule-consumer-adapter-v01/"
CONTRACT_PATH = f"{MODEL_ROOT}CONTRACT.json"
ADAPTER_PATH = f"{MODEL_ROOT}consume_schedule_v01.py"
TEST_PATH = f"{MODEL_ROOT}test_consume_schedule_v01.py"
READINESS_PATH = (
    f"{EVIDENCE_ROOT}SCHEDULE-CONSUMER-ZERO-CHILD-READINESS-V02.json"
)
INTEGRATION_INPUT_ROOT = "docs/production/evidence/INTEGRATION/"
FIXTURE_ROOT = f"{MODEL_ROOT}fixtures/"
POSTLOCK_FIXTURE_APPEARANCE_PATH = (
    f"{FIXTURE_ROOT}POSTLOCK-APPEARANCE-LOCK.json"
)
POSTLOCK_FIXTURE_PROFILE_PATH = (
    f"{FIXTURE_ROOT}POSTLOCK-SOURCE-PRODUCTION-PROFILE.json"
)
POSTLOCK_FIXTURE_RUNNER_PATH = f"{FIXTURE_ROOT}POSTLOCK-RUNNER-CONTRACT.json"
POSTLOCK_FIXTURE_SCHEDULE_PATH = f"{FIXTURE_ROOT}POSTLOCK-SCHEDULE.json"
BRANCH = "codex/citysim-world-art-south"
INTEGRATION_AUTHORITY = "401eb2ce19c5f5c932442ace72e66fbd734cfa35"
INTEGRATION_TREE = "c6f74e197a1882cf8df6f35a420920331edae142"
CLAIM_SHA256 = "f5bb4fa75f3a6170699966a4fe6f8c2fc5656d7765983999cf11ff179656ac82"

CLAIM = {
    "blobOid": "aaa0086c5df8ec706f8949d42776f756a3c4bbfb",
    "path": "docs/production/claims/PLAY-080.world-art-south.md",
    "revision": 5,
    "sha256": CLAIM_SHA256,
}
AUTHORITIES = {
    "directionScheduleAdapterAuthority": {
        "blobOid": "9bdcfc4428bceeea7cfc242c4b8c0ffbcdedd70b",
        "path": (
            "docs/production/evidence/INTEGRATION/"
            "INDUSTRIAL-L04-DIRECTION-SCHEDULE-ADAPTER-AUTHORITY.md"
        ),
        "sha256": "3638f960a9394f9c4c0c09e3aa75ba842ec4d093eada04762eb51f0b1c57dd34",
    },
    "familyContract": {
        "blobOid": "2bedaa3c25b6602806c8b24dc003214e14601279",
        "path": "docs/production/decisions/CONTRACT-010-directional-building-art.md",
        "sha256": "0ee2d68a9dba4694d92a864bfeb5a91970c88fe87d893e1898de7b26d38609af",
    },
    "scheduleSchema": {
        "blobOid": "dfa1473b40f2205b80684fe55f9e4c1463196b56",
        "path": (
            "docs/production/evidence/INTEGRATION/"
            "industrial-l04-parallel-execution-schedule-schema-v1.json"
        ),
        "sha256": "6eba2291f9cb548a8ddd08961bdffe3a18c9546b293a08f094711b38aa0840c6",
    },
    "scheduleSemanticValidator": {
        "blobOid": "9c1a7bb0254075015974e98f38de7a78597ed8d2",
        "path": (
            ".agents/skills/operate-citysim-integration/scripts/"
            "validate_industrial_l04_parallel_execution_schedule_v1.py"
        ),
        "sha256": "086ff2f2cb7d0c030d0039b48b3b66f7e6c314dd97a705b8f0a8a41fda0bbb04",
    },
}
ORCHESTRATOR = {
    "blobOid": "92155d1cf68efa78e3d2396c8cfe7c4794c9662c",
    "path": f"{SOURCE_ROOT}prepare_launch_binding.py",
    "sha256": "49869c480fd590422433b181263e332cc314e8a8bfce1f297e4fc774738a6896",
}
LOW_LEVEL_RUNNER = {
    "blobOid": "51d220d89de07e9550a03c4f849a2dd699238353",
    "path": f"{SOURCE_ROOT}run_production.py",
    "sha256": "80ac231be0b312d69eb55f10a8acee5ef2617a723570ca243d89c419718d5b27",
}
RUNNER_CONTRACT = {
    "blobOid": "bde316b55999a03b63316e89b02cdd8443b0bc33",
    "path": f"{SOURCE_ROOT}runner-contract.json",
    "sha256": "bc74613e9fdcc5b7c378488b0a5c3b5404087fb231da2b528b719597a1df03a2",
}
NONPRODUCTION_POSTLOCK_FIXTURE = {
    "appearanceLock": {
        "path": POSTLOCK_FIXTURE_APPEARANCE_PATH,
        "sha256": "20158b0b5473f7e43f2592296e7314df280d84897e1feaa2779235c1f1387c3f",
    },
    "runnerContract": {
        "path": POSTLOCK_FIXTURE_RUNNER_PATH,
        "sha256": "1efa2784708f5e509dc06cbef8520cef87e9af7b79df3c1bdd55847d26abaeba",
    },
    "schedule": {
        "path": POSTLOCK_FIXTURE_SCHEDULE_PATH,
        "sha256": "a3a94cbb35fa615bb1335cc3c1d42418b1ce1369b0ac18387d13b6e9af587960",
    },
    "sourceProductionProfile": {
        "path": POSTLOCK_FIXTURE_PROFILE_PATH,
        "sha256": "5edf57eaf42d5adb8c4ed892ed07fedff2900c935d55a883be29e6e3a662c1b8",
    },
    "mode": "nonproduction-zero-child-cli-proof",
}
PREDEISGN = {
    "materials": {
        "blobOid": "3a11708434c1df4e85e699b84bcf7a88fbf439e9",
        "path": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-080/"
            "industrial-l04-south-predesign-v01.materials.json"
        ),
        "sha256": "624b34f10354c79e0ced914ed55cf4dcb05468997d4efb679f881477984244fb",
    },
    "scene": {
        "blobOid": "d04d7630436430907caaeb4eaa9c2d04304190ad",
        "path": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-080/"
            "industrial-l04-south-predesign-v01.scene.json"
        ),
        "sha256": "e0c8dd02f261844daa3d78ba05c482acbbe9b08eac835a0f863621f48010b07d",
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
CURRENT_INPUTS = {
    "appearanceLock": MISSING_APPEARANCE_LOCK,
    "postLockSchedule": {"path": None, "sha256": None},
    "sourceProductionProfile": MISSING_PROFILE,
    "state": "blocked_missing_postlock_schedule_appearance_lock_and_source_profile",
}
SOURCE_EXCLUSIVE_ROOT = SOURCE_ROOT
EVIDENCE_EXCLUSIVE_ROOT = EVIDENCE_ROOT
PROCESS_OUTPUT_ROOTS = {
    process: f"{SOURCE_ROOT}outputs/process-{process}/"
    for process in ("A", "B", "C")
}
PROCESS_EVIDENCE_ROOTS = {
    process: f"{EVIDENCE_ROOT}process-{process}/"
    for process in ("A", "B", "C")
}
TARGET = {
    "baseCommit": INTEGRATION_AUTHORITY,
    "claimRevision": 5,
    "claimSha256": CLAIM_SHA256,
    "exclusiveRoots": [SOURCE_EXCLUSIVE_ROOT, EVIDENCE_EXCLUSIVE_ROOT],
    "phase": "postlock_abc",
    "processEvidenceRoots": PROCESS_EVIDENCE_ROOTS,
    "processOutputRoots": PROCESS_OUTPUT_ROOTS,
    "processes": ["A", "B", "C"],
    "queueTokens": ["south:A", "south:B", "south:C"],
}
ACTIVITY = {
    "blenderProcessLaunches": 0,
    "blenderRenderApiCalls": 0,
    "childStarts": 0,
    "contactSheetInvocations": 0,
    "dccProcessLaunches": 0,
    "imageGenInvocations": 0,
    "normalizerInvocations": 0,
    "pixelFiles": 0,
    "renderInvocations": 0,
    "sourcePackets": 0,
}
GATES = {
    "admissionAuthorized": False,
    "appearanceLockPresent": False,
    "childStartAuthorized": False,
    "dccAuthorized": False,
    "integrationAdmitted": False,
    "pixelProductionAuthorized": False,
    "postlockSchedulePresent": False,
    "productionSelected": False,
    "rendererQuarantined": False,
    "shippingAuthorized": False,
    "sourceProductionProfilePresent": False,
    "sourceReady": False,
}
OUTPUTS = {
    "adapter": ADAPTER_PATH,
    "contract": CONTRACT_PATH,
    "readinessPacket": READINESS_PATH,
    "tests": TEST_PATH,
}


class AdapterRejected(RuntimeError):
    """A deliberate rejection before any child start."""

    def __init__(self, code: str, details: Any = None):
        super().__init__(code)
        self.code = code
        self.details = details


@dataclass(frozen=True)
class CapturedFile:
    raw: bytes
    identity: tuple[int, int, int, int, int]


def reject(code: str, details: Any = None) -> None:
    raise AdapterRejected(code, details)


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


def require_exact_keys(value: Any, expected: set[str], label: str) -> dict[str, Any]:
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


def open_parent_descriptor(relative_path: str, code: str) -> tuple[int, str]:
    pure = parse_safe_relative_path(relative_path, code)
    flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
    descriptor = os.open(REPOSITORY_ROOT, flags)
    try:
        for component in pure.parts[:-1]:
            try:
                child = os.open(component, flags, dir_fd=descriptor)
            except OSError as error:
                reject(
                    code,
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


def inspect_path(relative_path: str) -> str:
    pure = parse_safe_relative_path(relative_path, "UNSAFE_OWNED_ROOT")
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
                    "PATH_REPLACEMENT_RACE",
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


def git(*arguments: str) -> str:
    result = subprocess.run(
        ["git", *arguments],
        cwd=REPOSITORY_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode:
        reject(
            "GIT_AUTHORITY_FAILURE",
            {"arguments": list(arguments), "stderr": result.stderr.strip()},
        )
    return result.stdout.strip()


def validate_binding_at_authority(role: str, binding: dict[str, str]) -> dict[str, str]:
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
    return {
        "role": role,
        "path": binding["path"],
        "sha256": digest,
        "blobOid": blob,
    }


def validate_contract(contract: dict[str, Any]) -> None:
    require_exact_keys(
        contract,
        {
            "acceptedPredesign",
            "activity",
            "authorities",
            "branch",
            "claim",
            "currentInputs",
            "direction",
            "disposition",
            "gates",
            "integrationAuthority",
            "mode",
            "nonproductionPostlockFixture",
            "orchestration",
            "orientationTransform",
            "outputs",
            "runnerContract",
            "schema",
            "target",
            "taskId",
        },
        "adapterContract",
    )
    expected_scalars = {
        "schema": "citysim.play-080.south-schedule-consumer-adapter.v2",
        "taskId": "PLAY-080",
        "direction": "south",
        "branch": BRANCH,
        "mode": "zero-pixel-direction-schedule-consumer-readiness",
        "orientationTransform": "none",
        "disposition": "ZERO_CHILD_READY_BLOCKED_PENDING_POSTLOCK_AUTHORITIES",
    }
    mismatches = {
        key: {"expected": expected, "actual": contract.get(key)}
        for key, expected in expected_scalars.items()
        if contract.get(key) != expected
    }
    if mismatches:
        reject("CONTRACT_IDENTITY_MISMATCH", mismatches)
    if contract.get("integrationAuthority") != INTEGRATION_RECORD:
        reject("STALE_INTEGRATION_AUTHORITY")
    if contract.get("claim") != CLAIM:
        reject("WRONG_CLAIM")
    if contract.get("authorities") != AUTHORITIES:
        reject("AUTHORITY_BINDING_MISMATCH")
    if contract.get("acceptedPredesign") != PREDEISGN:
        reject("ACCEPTED_PREDESIGN_BINDING_MISMATCH")
    if contract.get("runnerContract") != RUNNER_CONTRACT:
        reject("RUNNER_CONTRACT_BINDING_MISMATCH")
    if contract.get("nonproductionPostlockFixture") != NONPRODUCTION_POSTLOCK_FIXTURE:
        reject("NONPRODUCTION_FIXTURE_BINDING_MISMATCH")
    if contract.get("currentInputs") != CURRENT_INPUTS:
        reject("CURRENT_INPUT_STATE_MISMATCH")
    if contract.get("target") != TARGET:
        if contract.get("target", {}).get("claimRevision") != 5:
            reject("WRONG_CLAIM_REVISION")
        reject("TARGET_BINDING_MISMATCH")
    expected_orchestration = {
        "approvedHighLevelOrchestrator": ORCHESTRATOR,
        "directLowLevelInvocationAllowed": False,
        "forbiddenLowLevelRunner": LOW_LEVEL_RUNNER,
        "maximumChildStartsPerGrant": 1,
        "orchestratorOnly": True,
        "readinessChildStarts": 0,
    }
    if contract.get("orchestration") != expected_orchestration:
        reject("ORCHESTRATION_POLICY_MISMATCH")
    if contract.get("activity") != ACTIVITY:
        reject("ZERO_ACTIVITY_MISMATCH")
    if contract.get("gates") != GATES:
        reject("GATE_STATE_MISMATCH")
    if contract.get("outputs") != OUTPUTS:
        reject("OUTPUT_BINDING_MISMATCH")


def validate_runner_immutable(runner: dict[str, Any]) -> None:
    expected_scalars = {
        "schema": "citysim.world-art.prelock-runner-contract.v1",
        "taskId": "PLAY-080",
        "branch": BRANCH,
        "direction": "south",
        "sourceReady": False,
        "productionSelected": False,
    }
    mismatches = {
        key: {"expected": expected, "actual": runner.get(key)}
        for key, expected in expected_scalars.items()
        if runner.get(key) != expected
    }
    expected_predesign = {
        role: {
            "path": PREDEISGN[role]["path"],
            "sha256": PREDEISGN[role]["sha256"],
        }
        for role in ("materials", "scene")
    }
    actual_predesign = runner.get("acceptedPredesign", {})
    for role, expected in expected_predesign.items():
        if actual_predesign.get(role) != expected:
            mismatches[f"acceptedPredesign.{role}"] = {
                "expected": expected,
                "actual": actual_predesign.get(role),
            }
    expected_bridge = {
        "acceptedCandidateCommit": "3e01ca6738d7574718f9aeff4b66771eee109feb",
        "blenderNativeDirectionalSocket": [28, 0, 0],
        "canonicalCitySimSouthSocket": [0, 0, 28],
        "mappingContractSha256": (
            "5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7"
        ),
        "sourceSocketPixels": [640, 832],
        "state": "v06_revalidated",
    }
    actual_bridge = runner.get("coordinateBridge", {})
    for key, expected in expected_bridge.items():
        if actual_bridge.get(key) != expected:
            mismatches[f"coordinateBridge.{key}"] = {
                "expected": expected,
                "actual": actual_bridge.get(key),
            }
    launch_plan = runner.get("launchPlan", {})
    expected_launch = {
        "authorizedProcesses": ["A", "B", "C"],
        "isolatedOutputRoots": PROCESS_OUTPUT_ROOTS,
        "isolatedEvidenceRoots": PROCESS_EVIDENCE_ROOTS,
        "noOverwrite": True,
    }
    for key, expected in expected_launch.items():
        if launch_plan.get(key) != expected:
            mismatches[f"launchPlan.{key}"] = {
                "expected": expected,
                "actual": launch_plan.get(key),
            }
    if mismatches:
        reject("STALE_RUNNER_IMMUTABLE_BINDING", mismatches)


def validate_process_roots_missing() -> None:
    for role, path in {
        **{f"output-{key}": value for key, value in PROCESS_OUTPUT_ROOTS.items()},
        **{f"evidence-{key}": value for key, value in PROCESS_EVIDENCE_ROOTS.items()},
    }.items():
        state = inspect_path(path)
        if state == "symlink":
            reject("SYMLINK_PROCESS_ROOT", {"role": role, "path": path})
        if state != "missing":
            reject(
                "PROCESS_ROOT_PREEXISTS",
                {"role": role, "path": path, "state": state},
            )


def validate_prelock_runner(captured: CapturedFile) -> dict[str, Any]:
    if sha256_bytes(captured.raw) != RUNNER_CONTRACT["sha256"]:
        reject("STALE_PRELOCK_RUNNER_HASH")
    runner = load_json_bytes(captured.raw, RUNNER_CONTRACT["path"])
    validate_runner_immutable(runner)
    if runner.get("state") != "awaiting_appearance_lock":
        reject("RUNNER_STATE_NOT_PRELOCK", runner.get("state"))
    if runner.get("appearanceLock") != MISSING_APPEARANCE_LOCK:
        reject("APPEARANCE_LOCK_ALREADY_PRESENT")
    if runner.get("sourceProductionProfile") != MISSING_PROFILE:
        reject("SOURCE_PROFILE_ALREADY_PRESENT")
    return runner


def validate_postlock_runner(runner: dict[str, Any]) -> None:
    validate_runner_immutable(runner)
    if runner.get("state") != "appearance_lock_bound":
        reject("RUNNER_NOT_POSTLOCK_BOUND", runner.get("state"))


def validate_immutable_environment(contract: dict[str, Any]) -> dict[str, Any]:
    validate_contract(contract)
    branch = git("branch", "--show-current")
    if branch != BRANCH:
        reject("WRONG_BRANCH", {"expected": BRANCH, "actual": branch})
    ancestor = subprocess.run(
        ["git", "merge-base", "--is-ancestor", INTEGRATION_AUTHORITY, "HEAD"],
        cwd=REPOSITORY_ROOT,
        capture_output=True,
        check=False,
    )
    if ancestor.returncode:
        reject("STALE_INTEGRATION_AUTHORITY", INTEGRATION_AUTHORITY)
    tree = git("rev-parse", f"{INTEGRATION_AUTHORITY}^{{tree}}")
    if tree != INTEGRATION_TREE:
        reject("STALE_INTEGRATION_TREE", {"expected": INTEGRATION_TREE, "actual": tree})
    bindings = {
        "claim": CLAIM,
        **AUTHORITIES,
        "approvedHighLevelOrchestrator": ORCHESTRATOR,
        "forbiddenLowLevelRunner": LOW_LEVEL_RUNNER,
        "acceptedPredesign.materials": PREDEISGN["materials"],
        "acceptedPredesign.scene": PREDEISGN["scene"],
    }
    verified = [
        validate_binding_at_authority(role, binding)
        for role, binding in bindings.items()
    ]
    fixture_bindings = []
    for role, binding in NONPRODUCTION_POSTLOCK_FIXTURE.items():
        if role == "mode":
            continue
        captured = capture_file(binding["path"], "FIXTURE_INPUT_UNSAFE")
        digest = sha256_bytes(captured.raw)
        if digest != binding["sha256"]:
            reject(
                "NONPRODUCTION_FIXTURE_HASH_MISMATCH",
                {"role": role, "expected": binding["sha256"], "actual": digest},
            )
        fixture_bindings.append(
            {"role": role, "path": binding["path"], "sha256": digest}
        )
    validate_process_roots_missing()
    return {
        "branch": branch,
        "runtimeHeadPolicy": "integration-authority-is-ancestor",
        "bindings": verified,
        "nonproductionFixtureBindings": fixture_bindings,
    }


def validate_environment(contract: dict[str, Any]) -> dict[str, Any]:
    environment = validate_immutable_environment(contract)
    runner_capture = capture_file(
        RUNNER_CONTRACT["path"], "RUNNER_CONTRACT_UNSAFE"
    )
    validate_prelock_runner(runner_capture)
    return environment


def future_runner(schedule: dict[str, Any]) -> dict[str, Any]:
    runner = load_json_bytes(
        capture_file(RUNNER_CONTRACT["path"], "RUNNER_CONTRACT_UNSAFE").raw,
        RUNNER_CONTRACT["path"],
    )
    runner["state"] = "appearance_lock_bound"
    runner["appearanceLock"] = {
        "documentPath": schedule["appearanceLock"]["path"],
        "appearanceLockCommit": "c" * 40,
        "appearanceLockSha256": schedule["appearanceLock"]["sha256"],
        "northProcessASourceSha256": "d" * 64,
        "northProcessADecodedRgbaSha256": "e" * 64,
    }
    runner["sourceProductionProfile"] = {
        "path": schedule["sourceProductionProfile"]["path"],
        "commit": "f" * 40,
        "sha256": schedule["sourceProductionProfile"]["sha256"],
    }
    return runner


def synthetic_postlock_schedule() -> dict[str, Any]:
    directions = {
        "north": ("PLAY-027", "codex/citysim-world-art"),
        "east": ("PLAY-079", "codex/citysim-world-art-east"),
        "south": ("PLAY-080", BRANCH),
        "west": ("PLAY-081", "codex/citysim-world-art-west"),
    }
    slots = ["dcc-1", "dcc-2", "dcc-3"]
    queue: list[str] = []
    grants = []
    for direction, (claim, branch) in directions.items():
        processes = []
        for index, process in enumerate(("A", "B", "C")):
            granted = direction != "north" or process != "A"
            if granted:
                queue.append(f"{direction}:{process}")
            processes.append(
                {
                    "grantId": f"fixture-{direction}-{process}",
                    "process": process,
                    "state": "granted" if granted else "blocked",
                    "slotId": slots[index % len(slots)] if granted else None,
                    "maximumChildStarts": 1 if granted else 0,
                    "orchestratorOnly": True,
                    "directLowLevelInvocationAllowed": False,
                }
            )
        grants.append(
            {
                "direction": direction,
                "claim": claim,
                "branch": branch,
                "claimSha256": CLAIM_SHA256 if direction == "south" else "0" * 64,
                "baseCommit": INTEGRATION_AUTHORITY,
                "orchestrator": {
                    "path": ORCHESTRATOR["path"],
                    "sha256": ORCHESTRATOR["sha256"],
                },
                "exclusiveRoots": (
                    [SOURCE_EXCLUSIVE_ROOT, EVIDENCE_EXCLUSIVE_ROOT]
                    if direction == "south"
                    else [
                        f"Native/nonproduction/{direction}/",
                        f"docs/nonproduction/{direction}/",
                    ]
                ),
                "processes": processes,
            }
        )
    return {
        "schema": 1,
        "batch": "industrial_l04_directional_family",
        "phase": "postlock_abc",
        "issuedAt": "2026-07-30T00:00:00Z",
        "integrationAuthorityCommit": INTEGRATION_AUTHORITY,
        "familyContract": {
            "path": AUTHORITIES["familyContract"]["path"],
            "sha256": AUTHORITIES["familyContract"]["sha256"],
        },
        "appearanceLock": {
            "path": "docs/production/evidence/INTEGRATION/FUTURE-APPEARANCE-LOCK.json",
            "sha256": "a" * 64,
        },
        "sourceProductionProfile": {
            "path": "docs/production/evidence/INTEGRATION/FUTURE-SOURCE-PROFILE.json",
            "sha256": "b" * 64,
        },
        "computeEnvelope": {
            "maximumSimultaneousDCCProcesses": 3,
            "slotIds": slots,
            "queueOrder": queue,
        },
        "directionGrants": grants,
    }


def south_grant(schedule: dict[str, Any]) -> dict[str, Any]:
    grants = [
        grant
        for grant in schedule.get("directionGrants", [])
        if isinstance(grant, dict) and grant.get("direction") == "south"
    ]
    if len(grants) != 1:
        reject("WRONG_DIRECTION", {"southGrantCount": len(grants)})
    return grants[0]


def validate_schedule_core(
    schedule: dict[str, Any] | None,
    contract: dict[str, Any],
    runner: dict[str, Any],
) -> dict[str, Any]:
    if schedule is None:
        reject("MISSING_SCHEDULE")
    if contract.get("target", {}).get("claimRevision") != 5:
        reject("WRONG_CLAIM_REVISION")
    if schedule.get("phase") != "postlock_abc":
        reject("WRONG_PHASE", schedule.get("phase"))
    if schedule.get("integrationAuthorityCommit") != INTEGRATION_AUTHORITY:
        reject("STALE_SCHEDULE_AUTHORITY")
    if schedule.get("familyContract") != {
        "path": AUTHORITIES["familyContract"]["path"],
        "sha256": AUTHORITIES["familyContract"]["sha256"],
    }:
        reject("WRONG_FAMILY_CONTRACT")
    grant = south_grant(schedule)
    expected_identity = {
        "claim": "PLAY-080",
        "branch": BRANCH,
        "claimSha256": CLAIM_SHA256,
        "baseCommit": INTEGRATION_AUTHORITY,
    }
    for key, expected in expected_identity.items():
        if grant.get(key) != expected:
            codes = {
                "claim": "WRONG_CLAIM",
                "branch": "WRONG_BRANCH",
                "claimSha256": "WRONG_CLAIM_HASH",
                "baseCommit": "WRONG_BASE",
            }
            reject(codes[key], {"expected": expected, "actual": grant.get(key)})
    if grant.get("orchestrator") != {
        "path": ORCHESTRATOR["path"],
        "sha256": ORCHESTRATOR["sha256"],
    }:
        reject("WRONG_ORCHESTRATOR")
    if grant.get("exclusiveRoots") != TARGET["exclusiveRoots"]:
        reject("WRONG_EXCLUSIVE_ROOTS")
    appearance = schedule.get("appearanceLock")
    profile = schedule.get("sourceProductionProfile")
    if appearance is None:
        reject("MISSING_APPEARANCE_LOCK")
    if profile is None:
        reject("MISSING_SOURCE_PRODUCTION_PROFILE")
    validate_postlock_runner(runner)
    runner_lock = runner.get("appearanceLock", {})
    expected_appearance = {
        "path": runner_lock.get("documentPath"),
        "sha256": runner_lock.get("appearanceLockSha256"),
    }
    if appearance != expected_appearance:
        reject(
            "WRONG_APPEARANCE_LOCK",
            {"expected": expected_appearance, "actual": appearance},
        )
    runner_profile = runner.get("sourceProductionProfile", {})
    expected_profile = {
        "path": runner_profile.get("path"),
        "sha256": runner_profile.get("sha256"),
    }
    if profile != expected_profile:
        reject(
            "WRONG_SOURCE_PRODUCTION_PROFILE",
            {"expected": expected_profile, "actual": profile},
        )
    launch_plan = runner.get("launchPlan", {})
    if launch_plan.get("isolatedOutputRoots") != PROCESS_OUTPUT_ROOTS:
        reject("WRONG_PROCESS_OUTPUT_ROOTS")
    if launch_plan.get("isolatedEvidenceRoots") != PROCESS_EVIDENCE_ROOTS:
        reject("WRONG_PROCESS_EVIDENCE_ROOTS")
    processes = grant.get("processes")
    if not isinstance(processes, list) or len(processes) != 3:
        reject("WRONG_PROCESS_SET")
    by_process = {
        process.get("process"): process
        for process in processes
        if isinstance(process, dict)
    }
    if set(by_process) != {"A", "B", "C"}:
        reject("WRONG_PROCESS_SET")
    envelope = schedule.get("computeEnvelope", {})
    slots = envelope.get("slotIds")
    if (
        not isinstance(slots, list)
        or len(set(slots)) != len(slots)
        or envelope.get("maximumSimultaneousDCCProcesses", 0) < 3
    ):
        reject("WRONG_SLOT_ENVELOPE")
    for process in ("A", "B", "C"):
        record = by_process[process]
        if record.get("state") != "granted":
            reject("MISSING_PROCESS_GRANT", process)
        if record.get("slotId") not in slots:
            reject("WRONG_SLOT", {"process": process, "slot": record.get("slotId")})
        if record.get("maximumChildStarts") != 1:
            reject("WRONG_CHILD_LIMIT", process)
        if record.get("orchestratorOnly") is not True:
            reject("ORCHESTRATOR_ONLY_REQUIRED", process)
        if record.get("directLowLevelInvocationAllowed") is not False:
            reject("DIRECT_LOW_LEVEL_INVOCATION_FORBIDDEN", process)
    queue = envelope.get("queueOrder")
    if not isinstance(queue, list):
        reject("WRONG_QUEUE")
    tokens = TARGET["queueTokens"]
    try:
        positions = [queue.index(token) for token in tokens]
    except ValueError:
        reject("WRONG_QUEUE", queue)
    if positions != sorted(positions):
        reject("WRONG_QUEUE", {"tokens": tokens, "positions": positions})
    if contract.get("orchestration", {}).get("directLowLevelInvocationAllowed") is not False:
        reject("DIRECT_LOW_LEVEL_INVOCATION_FORBIDDEN")
    return {
        "result": "VALIDATED_FOR_HIGH_LEVEL_ORCHESTRATOR",
        "direction": "south",
        "phase": "postlock_abc",
        "grants": [
            {
                "process": process,
                "grantId": by_process[process]["grantId"],
                "slotId": by_process[process]["slotId"],
                "maximumChildStarts": 1,
            }
            for process in ("A", "B", "C")
        ],
        "approvedHighLevelOrchestrator": {
            "path": ORCHESTRATOR["path"],
            "sha256": ORCHESTRATOR["sha256"],
        },
        "childrenStarted": 0,
        "directLowLevelInvocationAllowed": False,
    }


def run_adversaries(contract: dict[str, Any]) -> list[dict[str, str]]:
    baseline = synthetic_postlock_schedule()
    baseline_runner = future_runner(baseline)
    cases: list[tuple[str, str, Any]] = []
    cases.append(("missing-schedule", "MISSING_SCHEDULE", None))

    def mutation(case_id: str, code: str, mutate: Any) -> None:
        candidate = copy.deepcopy(baseline)
        candidate_contract = copy.deepcopy(contract)
        candidate_runner = copy.deepcopy(baseline_runner)
        mutate(candidate, candidate_contract, candidate_runner)
        cases.append((case_id, code, (candidate, candidate_contract, candidate_runner)))

    mutation(
        "stale-schedule-authority",
        "STALE_SCHEDULE_AUTHORITY",
        lambda schedule, _contract, _runner: schedule.update(
            integrationAuthorityCommit="a" * 40
        ),
    )
    mutation(
        "wrong-phase",
        "WRONG_PHASE",
        lambda schedule, _contract, _runner: schedule.update(phase="prelock_north_a"),
    )
    mutation(
        "wrong-direction",
        "WRONG_DIRECTION",
        lambda schedule, _contract, _runner: south_grant(schedule).update(
            direction="north"
        ),
    )
    mutation(
        "wrong-claim",
        "WRONG_CLAIM",
        lambda schedule, _contract, _runner: south_grant(schedule).update(
            claim="PLAY-081"
        ),
    )
    mutation(
        "wrong-claim-revision",
        "WRONG_CLAIM_REVISION",
        lambda _schedule, contract_value, _runner: contract_value["target"].update(
            claimRevision=4
        ),
    )
    mutation(
        "wrong-claim-hash",
        "WRONG_CLAIM_HASH",
        lambda schedule, _contract, _runner: south_grant(schedule).update(
            claimSha256="a" * 64
        ),
    )
    mutation(
        "wrong-base",
        "WRONG_BASE",
        lambda schedule, _contract, _runner: south_grant(schedule).update(
            baseCommit="a" * 40
        ),
    )
    mutation(
        "wrong-slot",
        "WRONG_SLOT",
        lambda schedule, _contract, _runner: south_grant(schedule)["processes"][
            0
        ].update(slotId="dcc-unknown"),
    )
    mutation(
        "wrong-queue",
        "WRONG_QUEUE",
        lambda schedule, _contract, _runner: schedule["computeEnvelope"][
            "queueOrder"
        ].remove("south:B"),
    )
    mutation(
        "wrong-roots",
        "WRONG_EXCLUSIVE_ROOTS",
        lambda schedule, _contract, _runner: south_grant(schedule).update(
            exclusiveRoots=[
                "Native/CitySimNative/WorldArt/Blender/PLAY-079/",
                EVIDENCE_EXCLUSIVE_ROOT,
            ]
        ),
    )
    mutation(
        "wrong-orchestrator",
        "WRONG_ORCHESTRATOR",
        lambda schedule, _contract, _runner: south_grant(schedule)[
            "orchestrator"
        ].update(sha256="a" * 64),
    )
    mutation(
        "missing-appearance-lock",
        "MISSING_APPEARANCE_LOCK",
        lambda schedule, _contract, _runner: schedule.update(appearanceLock=None),
    )
    mutation(
        "wrong-appearance-lock",
        "WRONG_APPEARANCE_LOCK",
        lambda schedule, _contract, _runner: schedule["appearanceLock"].update(
            sha256="f" * 64
        ),
    )
    mutation(
        "missing-source-profile",
        "MISSING_SOURCE_PRODUCTION_PROFILE",
        lambda schedule, _contract, _runner: schedule.update(
            sourceProductionProfile=None
        ),
    )
    mutation(
        "wrong-source-profile",
        "WRONG_SOURCE_PRODUCTION_PROFILE",
        lambda schedule, _contract, _runner: schedule[
            "sourceProductionProfile"
        ].update(sha256="f" * 64),
    )
    mutation(
        "prelock-runner",
        "RUNNER_NOT_POSTLOCK_BOUND",
        lambda _schedule, _contract, runner: runner.update(
            state="awaiting_appearance_lock",
            appearanceLock=copy.deepcopy(MISSING_APPEARANCE_LOCK),
            sourceProductionProfile=copy.deepcopy(MISSING_PROFILE),
        ),
    )
    mutation(
        "stale-runner-immutable-predesign",
        "STALE_RUNNER_IMMUTABLE_BINDING",
        lambda _schedule, _contract, runner: runner["acceptedPredesign"][
            "scene"
        ].update(sha256="f" * 64),
    )
    mutation(
        "wrong-child-limit",
        "WRONG_CHILD_LIMIT",
        lambda schedule, _contract, _runner: south_grant(schedule)["processes"][
            1
        ].update(maximumChildStarts=0),
    )
    mutation(
        "orchestrator-only-disabled",
        "ORCHESTRATOR_ONLY_REQUIRED",
        lambda schedule, _contract, _runner: south_grant(schedule)["processes"][
            1
        ].update(orchestratorOnly=False),
    )
    mutation(
        "direct-low-level-enabled",
        "DIRECT_LOW_LEVEL_INVOCATION_FORBIDDEN",
        lambda schedule, _contract, _runner: south_grant(schedule)["processes"][
            2
        ].update(directLowLevelInvocationAllowed=True),
    )
    results: list[dict[str, str]] = []
    for case_id, expected, inputs in cases:
        try:
            if inputs is None:
                validate_schedule_core(None, contract, baseline_runner)
            else:
                validate_schedule_core(*inputs)
        except AdapterRejected as error:
            if error.code != expected:
                reject(
                    "ADVERSARY_WRONG_REJECTION",
                    {"id": case_id, "expected": expected, "actual": error.code},
                )
            results.append(
                {
                    "id": case_id,
                    "rejectionCode": error.code,
                    "result": "PASS_ZERO_CHILD_FAIL_CLOSED",
                }
            )
        else:
            reject("ADVERSARY_FAILED_OPEN", case_id)
    return results


def load_shared_validator() -> Any:
    binding = AUTHORITIES["scheduleSemanticValidator"]
    captured = capture_file(binding["path"], "SCHEDULE_VALIDATOR_UNSAFE")
    if sha256_bytes(captured.raw) != binding["sha256"]:
        reject("STALE_SCHEDULE_VALIDATOR")
    absolute = REPOSITORY_ROOT.joinpath(*PurePosixPath(binding["path"]).parts)
    spec = importlib.util.spec_from_file_location(
        "industrial_l04_schedule_validator_v1", absolute
    )
    if spec is None or spec.loader is None:
        reject("SCHEDULE_VALIDATOR_IMPORT_FAILED")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def consume_schedule_path(
    schedule_path: str,
    contract: dict[str, Any],
    nonproduction_fixture: bool = False,
) -> dict[str, Any]:
    pure = parse_safe_relative_path(schedule_path, "UNSAFE_SCHEDULE_PATH")
    if nonproduction_fixture:
        if schedule_path != POSTLOCK_FIXTURE_SCHEDULE_PATH:
            reject("FIXTURE_SCHEDULE_PATH_MISMATCH", schedule_path)
        runner_path = POSTLOCK_FIXTURE_RUNNER_PATH
    elif pure.as_posix().startswith(INTEGRATION_INPUT_ROOT):
        runner_path = RUNNER_CONTRACT["path"]
    else:
        reject("SCHEDULE_PATH_NOT_INTEGRATION_OWNED", schedule_path)
    first = capture_file(schedule_path, "SCHEDULE_INPUT_UNSAFE")
    if nonproduction_fixture:
        expected_schedule_hash = NONPRODUCTION_POSTLOCK_FIXTURE["schedule"][
            "sha256"
        ]
        if sha256_bytes(first.raw) != expected_schedule_hash:
            reject("NONPRODUCTION_FIXTURE_HASH_MISMATCH", "schedule")
    schedule = load_json_bytes(first.raw, schedule_path)
    shared_validator = load_shared_validator()
    absolute = REPOSITORY_ROOT.joinpath(*pure.parts)
    try:
        shared_result = shared_validator.validate(REPOSITORY_ROOT, absolute)
    except Exception as error:
        reject("SHARED_SCHEDULE_VALIDATION_FAILED", str(error))
    if not isinstance(shared_result, dict):
        reject("SHARED_SCHEDULE_VALIDATION_FAILED", "result-not-object")
    shared_result = copy.deepcopy(shared_result)
    shared_result["schedule"] = schedule_path
    second = capture_file(schedule_path, "SCHEDULE_INPUT_UNSAFE")
    if first.identity != second.identity or first.raw != second.raw:
        reject("SCHEDULE_REPLACEMENT_RACE")
    runner_capture = capture_file(runner_path, "RUNNER_CONTRACT_UNSAFE")
    if nonproduction_fixture:
        expected_runner_hash = NONPRODUCTION_POSTLOCK_FIXTURE["runnerContract"][
            "sha256"
        ]
        if sha256_bytes(runner_capture.raw) != expected_runner_hash:
            reject("NONPRODUCTION_FIXTURE_HASH_MISMATCH", "runnerContract")
    runner = load_json_bytes(runner_capture.raw, runner_path)
    result = validate_schedule_core(schedule, contract, runner)
    return {
        **result,
        "nonproductionFixture": nonproduction_fixture,
        "runner": {
            "path": runner_path,
            "sha256": sha256_bytes(runner_capture.raw),
            "stage": runner["state"],
        },
        "schedule": {
            "path": schedule_path,
            "sha256": sha256_bytes(first.raw),
            "sharedSemanticValidation": shared_result,
        },
    }


def build_readiness_packet(
    contract_capture: CapturedFile,
    contract: dict[str, Any],
    environment: dict[str, Any],
) -> dict[str, Any]:
    implementation = {}
    for role, path in (
        ("contract", CONTRACT_PATH),
        ("adapter", ADAPTER_PATH),
        ("tests", TEST_PATH),
    ):
        captured = capture_file(path, "IMPLEMENTATION_INPUT_UNSAFE")
        implementation[role] = {"path": path, "sha256": sha256_bytes(captured.raw)}
    adversaries = run_adversaries(contract)
    postlock_fixture_result = consume_schedule_path(
        POSTLOCK_FIXTURE_SCHEDULE_PATH,
        contract,
        nonproduction_fixture=True,
    )
    return {
        "activity": ACTIVITY,
        "adversarialCases": adversaries,
        "branch": BRANCH,
        "childStartResult": {
            "childrenStarted": 0,
            "directLowLevelInvocationAllowed": False,
            "highLevelOrchestratorInvocations": 0,
            "result": "ZERO_CHILD",
        },
        "currentInputs": CURRENT_INPUTS,
        "direction": "south",
        "disposition": "ZERO_CHILD_READY_BLOCKED_PENDING_POSTLOCK_AUTHORITIES",
        "gates": GATES,
        "implementation": implementation,
        "integrationAuthority": INTEGRATION_RECORD,
        "postlockCliBoundary": postlock_fixture_result,
        "result": "PASS_ZERO_CHILD_READY",
        "schema": "citysim.play-080.south-schedule-consumer-readiness.v2",
        "target": TARGET,
        "taskId": "PLAY-080",
        "validation": {
            "environment": environment,
            "failClosedCases": len(adversaries),
            "scheduleSemanticValidator": {
                "path": AUTHORITIES["scheduleSemanticValidator"]["path"],
                "sha256": AUTHORITIES["scheduleSemanticValidator"]["sha256"],
                "status": "PASS_NONPRODUCTION_POSTLOCK_FIXTURE",
            },
            "scheduleSchema": {
                "path": AUTHORITIES["scheduleSchema"]["path"],
                "sha256": AUTHORITIES["scheduleSchema"]["sha256"],
                "status": "PASS_NONPRODUCTION_POSTLOCK_FIXTURE",
            },
            "status": "PASS",
        },
    }


def deterministic_readiness_packet() -> dict[str, Any]:
    first_contract = capture_file(CONTRACT_PATH, "ADAPTER_CONTRACT_UNSAFE")
    first_payload = load_json_bytes(first_contract.raw, CONTRACT_PATH)
    first_environment = validate_environment(first_payload)
    first_packet = build_readiness_packet(
        first_contract, first_payload, first_environment
    )
    second_contract = capture_file(CONTRACT_PATH, "ADAPTER_CONTRACT_UNSAFE")
    second_payload = load_json_bytes(second_contract.raw, CONTRACT_PATH)
    second_environment = validate_environment(second_payload)
    second_packet = build_readiness_packet(
        second_contract, second_payload, second_environment
    )
    first_bytes = canonical_bytes(first_packet)
    second_bytes = canonical_bytes(second_packet)
    if (
        first_contract.identity != second_contract.identity
        or first_contract.raw != second_contract.raw
        or first_bytes != second_bytes
    ):
        reject("READINESS_REPLAY_NOT_IDENTICAL")
    packet = copy.deepcopy(first_packet)
    packet["replay"] = {
        "byteIdentical": True,
        "payloadSha256": [sha256_bytes(first_bytes), sha256_bytes(second_bytes)],
        "runs": 2,
        "stableContractIdentity": True,
    }
    return packet


def write_exclusive(relative_path: str, raw: bytes) -> None:
    parent, leaf = open_parent_descriptor(relative_path, "UNSAFE_READINESS_PATH")
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
                reject("UNSAFE_READINESS_PATH", relative_path)
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
    mode.add_argument("--readiness-dry-run", action="store_true")
    mode.add_argument("--write-readiness", action="store_true")
    mode.add_argument("--verify-readiness", action="store_true")
    mode.add_argument("--consume", action="store_true")
    parser.add_argument("--contract", default=CONTRACT_PATH)
    parser.add_argument("--readiness", default=READINESS_PATH)
    parser.add_argument("--schedule")
    parser.add_argument("--nonproduction-postlock-fixture", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        if args.contract != CONTRACT_PATH:
            reject("CONTRACT_PATH_MISMATCH", args.contract)
        if args.readiness != READINESS_PATH:
            reject("READINESS_PATH_MISMATCH", args.readiness)
        contract_capture = capture_file(CONTRACT_PATH, "ADAPTER_CONTRACT_UNSAFE")
        contract = load_json_bytes(contract_capture.raw, CONTRACT_PATH)
        if args.consume:
            validate_immutable_environment(contract)
            if not args.schedule:
                reject("MISSING_SCHEDULE")
            result = consume_schedule_path(
                args.schedule,
                contract,
                nonproduction_fixture=args.nonproduction_postlock_fixture,
            )
            print(
                json.dumps(
                    {
                        **result,
                        "activity": ACTIVITY,
                        "reportWritten": False,
                    },
                    sort_keys=True,
                )
            )
            return 0
        environment = validate_environment(contract)
        if args.nonproduction_postlock_fixture:
            reject("FIXTURE_MODE_REQUIRES_CONSUME")
        if args.schedule is not None:
            reject("SCHEDULE_NOT_ALLOWED_IN_READINESS_MODE")
        packet = deterministic_readiness_packet()
        raw = canonical_bytes(packet)
        digest = sha256_bytes(raw)
        if args.write_readiness:
            write_exclusive(READINESS_PATH, raw)
            action = "WROTE_EXCLUSIVE"
            written = True
        elif args.verify_readiness:
            captured = capture_file(READINESS_PATH, "READINESS_INPUT_UNSAFE")
            if captured.raw != raw:
                reject(
                    "READINESS_CONTENT_MISMATCH",
                    {"expected": digest, "actual": sha256_bytes(captured.raw)},
                )
            action = "VERIFIED_READ_ONLY"
            written = False
        else:
            action = "DRY_RUN"
            written = False
        print(
            json.dumps(
                {
                    "action": action,
                    "childrenStarted": 0,
                    "failClosedCases": len(packet["adversarialCases"]),
                    "pixelFiles": 0,
                    "readinessPath": READINESS_PATH,
                    "readinessSha256": digest,
                    "reportWritten": written,
                    "result": packet["result"],
                    "sourceReady": False,
                },
                sort_keys=True,
            )
        )
        return 0
    except AdapterRejected as error:
        print(
            json.dumps(
                {
                    "activity": ACTIVITY,
                    "childrenStarted": 0,
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
