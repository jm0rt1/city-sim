#!/usr/bin/env python3
"""Consume an Integration schedule for PLAY-079 without starting any child."""

from __future__ import annotations

import argparse
import ast
import copy
import hashlib
import importlib.util
import json
import pathlib
import subprocess
import sys
from typing import Any, NoReturn


VERSION_ROOT = pathlib.Path(__file__).resolve().parent
SOURCE_ROOT = VERSION_ROOT.parent
REPOSITORY_ROOT = VERSION_ROOT.parents[6]
CONTRACT_RELATIVE = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
    "industrial-l04-east-source-v01/schedule-consumer-adapter-v01/"
    "SCHEDULE-CONSUMER-CONTRACT.json"
)
ADAPTER_RELATIVE = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
    "industrial-l04-east-source-v01/schedule-consumer-adapter-v01/"
    "consume_parallel_schedule_v1.py"
)
TEST_RELATIVE = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
    "industrial-l04-east-source-v01/schedule-consumer-adapter-v01/"
    "test_consume_parallel_schedule_v1.py"
)
PACKET_RELATIVE = (
    "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/"
    "schedule-consumer-adapter-v01/ZERO-CHILD-READINESS.json"
)
PUBLISHED_BASE = "aaee294718a8176b70a4688b738b517f216dd3a7"
AUTHORITY_DECLARED_BASE = "be524831885fc240742f61be7357ea515a78da32"
AUTHORED_BRANCH = "codex/citysim-world-art-east"
ALLOWED_REPLAY_BRANCHES = {AUTHORED_BRANCH, "master"}
CLAIM_REVISION = 7
CLAIM_SHA256 = "4cfefea0dc0502af8123305356df131ca2b19a13bedf26e82161ea052706469a"
INTEGRATION_PREFIX = "docs/production/evidence/INTEGRATION/"
EXPECTED_EXCLUSIVE_ROOTS = [
    (
        "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
        "industrial-l04-east-source-v01/"
    ),
    "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/",
]
EXPECTED_PROCESS_ROOTS = {
    process: {
        "outputRoot": (
            "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/"
            f"renders/process-{process.lower()}/"
        ),
        "evidenceRoot": (
            "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/"
            f"execution/process-{process.lower()}/"
        ),
    }
    for process in "ABC"
}
MISSING_SCHEDULE = {
    "state": "missing",
    "path": None,
    "commit": None,
    "sha256": None,
    "requiredPhase": "postlock_abc",
}
MISSING_FILE_BINDING = {
    "state": "missing",
    "path": None,
    "sha256": None,
}
ZERO_READINESS = {
    "scheduleValidated": False,
    "grantValidated": False,
    "launchReady": False,
    "sourceReady": False,
    "production": False,
    "childStarts": 0,
    "blenderChildStarts": 0,
    "dccChildStarts": 0,
    "renderInvocations": 0,
    "pixelFilesCreated": 0,
}


class AdapterRejected(RuntimeError):
    """Stable fail-closed schedule-consumer rejection."""

    def __init__(self, code: str, detail: object):
        super().__init__(str(detail))
        self.code = code
        self.detail = str(detail)


def reject(code: str, detail: object) -> NoReturn:
    raise AdapterRejected(code, detail)


def canonical_bytes(value: object) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
        + "\n"
    ).encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def load_module(path: pathlib.Path, name: str) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        reject("module_import_failed", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


HARDENED = load_module(
    SOURCE_ROOT / "replay_current_master_inputs.py",
    "play079_schedule_capture",
)


EXPECTED_BINDINGS = {
    "claim": {
        "path": "docs/production/claims/PLAY-079.world-art-east.md",
        "sha256": CLAIM_SHA256,
    },
    "adapterAuthority": {
        "path": (
            "docs/production/evidence/INTEGRATION/"
            "INDUSTRIAL-L04-DIRECTION-SCHEDULE-ADAPTER-AUTHORITY.md"
        ),
        "sha256": "3638f960a9394f9c4c0c09e3aa75ba842ec4d093eada04762eb51f0b1c57dd34",
    },
    "scheduleSchema": {
        "path": (
            "docs/production/evidence/INTEGRATION/"
            "industrial-l04-parallel-execution-schedule-schema-v1.json"
        ),
        "sha256": "6eba2291f9cb548a8ddd08961bdffe3a18c9546b293a08f094711b38aa0840c6",
    },
    "scheduleSemanticValidator": {
        "path": (
            ".agents/skills/operate-citysim-integration/scripts/"
            "validate_industrial_l04_parallel_execution_schedule_v1.py"
        ),
        "sha256": "086ff2f2cb7d0c030d0039b48b3b66f7e6c314dd97a705b8f0a8a41fda0bbb04",
    },
    "highLevelOrchestrator": {
        "path": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
            "industrial-l04-east-source-v01/orchestrate_parallel_source.py"
        ),
        "sha256": "5c9f5ffcebc2a804bb43d593a3be35d280908afeaf7f02b2860675035ad16406",
    },
    "processPreparation": {
        "path": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
            "industrial-l04-east-source-v01/parallel-process-prep-v01/"
            "PROCESS-ORCHESTRATION-PREP-CONTRACT.json"
        ),
        "sha256": "cc6b0c2653af9e563ad60e27bfe8cde3d3f3e67d74153533ca06eef7ad08aaf6",
    },
    "scene": {
        "path": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
            "industrial-l04-east-predesign-v01/scene.json"
        ),
        "sha256": "e19c70693ea57a7f23669d5e93354eee0a8fa42be16e68b38d00f5608a500db7",
    },
    "materials": {
        "path": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
            "industrial-l04-east-predesign-v01/materials.json"
        ),
        "sha256": "1d0eda7be1e50d9fd98247cb63035443e904a2724583df1fbb328140b63ef9b9",
    },
}
WORKER_HEAD_BINDINGS = {"highLevelOrchestrator"}


def require_object(value: object, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        reject("shape_invalid", f"{label}: expected object")
    return value


def load_json(payload: bytes, label: str) -> dict[str, Any]:
    try:
        value = json.loads(payload)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise AdapterRejected(f"{label}_json_invalid", error) from error
    return require_object(value, label)


def require_equal(actual: object, expected: object, code: str) -> None:
    if actual != expected:
        reject(code, f"{actual!r} != {expected!r}")


def git_is_ancestor(ancestor: str, descendant: str, code: str) -> None:
    result = subprocess.run(
        ["git", "merge-base", "--is-ancestor", ancestor, descendant],
        cwd=REPOSITORY_ROOT,
        check=False,
        capture_output=True,
    )
    if result.returncode:
        reject(code, f"{ancestor} !<= {descendant}")


def branch_identity() -> dict[str, object]:
    branch = subprocess.run(
        ["git", "branch", "--show-current"],
        cwd=REPOSITORY_ROOT,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    if branch not in ALLOWED_REPLAY_BRANCHES:
        reject("branch_mismatch", branch)
    head = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=REPOSITORY_ROOT,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    git_is_ancestor(PUBLISHED_BASE, head, "published_base_not_ancestor")
    return {
        "authoredBranch": AUTHORED_BRANCH,
        "replayBranch": branch,
        "publishedBase": PUBLISHED_BASE,
        "publishedBaseAncestorOfReplayHead": True,
    }


def validate_binding(
    name: str, declared: object
) -> tuple[dict[str, str], bytes]:
    expected = EXPECTED_BINDINGS[name]
    binding = require_object(declared, f"bindings.{name}")
    require_equal(binding.get("path"), expected["path"], f"{name}_path_mismatch")
    require_equal(binding.get("sha256"), expected["sha256"], f"{name}_hash_mismatch")
    try:
        binding_commit = (
            subprocess.run(
                ["git", "rev-parse", "HEAD"],
                cwd=REPOSITORY_ROOT,
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip()
            if name in WORKER_HEAD_BINDINGS
            else PUBLISHED_BASE
        )
        blob, tree = HARDENED.git_blob(
            binding_commit, expected["path"], f"scheduleAdapter.{name}"
        )
        working = HARDENED.capture_repository_file(
            expected["path"], f"scheduleAdapter.{name}"
        )
    except HARDENED.ReplayRejected as error:
        raise AdapterRejected(error.code, error.detail) from error
    require_equal(
        sha256_bytes(blob), expected["sha256"], f"{name}_git_blob_hash_mismatch"
    )
    require_equal(
        sha256_bytes(working), expected["sha256"], f"{name}_working_hash_mismatch"
    )
    return {
        "path": expected["path"],
        "sha256": expected["sha256"],
        "authorityCommit": binding_commit,
        "gitMode": tree["mode"],
        "gitObjectId": tree["objectId"],
    }, working


def validate_no_launch_api() -> dict[str, object]:
    payload = HARDENED.capture_repository_file(ADAPTER_RELATIVE, "adapterSource")
    tree = ast.parse(payload.decode("utf-8"), filename=ADAPTER_RELATIVE)
    forbidden_imports = {
        "run_production",
        "bpy",
        "east_output_safety",
        "orchestrate_parallel_source",
    }
    forbidden_calls = {
        "Popen",
        "execv",
        "execve",
        "execl",
        "spawnl",
        "spawnv",
        "system",
    }
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                if alias.name.split(".")[0] in forbidden_imports:
                    reject("direct_low_level_import_present", alias.name)
        if isinstance(node, ast.ImportFrom):
            if (node.module or "").split(".")[0] in forbidden_imports:
                reject("direct_low_level_import_present", node.module)
        if isinstance(node, ast.Call):
            function = node.func
            name = (
                function.id
                if isinstance(function, ast.Name)
                else function.attr
                if isinstance(function, ast.Attribute)
                else ""
            )
            if name in forbidden_calls:
                reject("child_launch_api_present", name)
    return {
        "launchApiPresent": False,
        "lowLevelRunnerImported": False,
        "highLevelOrchestratorImported": False,
        "directLowLevelInvocationPossible": False,
    }


def validate_contract(value: dict[str, Any]) -> dict[str, Any]:
    require_equal(
        value.get("schema"),
        "citysim.play-079.east-schedule-consumer-adapter.v1",
        "contract_schema_mismatch",
    )
    require_equal(value.get("schemaVersion"), 1, "schema_version_mismatch")
    require_equal(value.get("taskId"), "PLAY-079", "task_mismatch")
    require_equal(value.get("direction"), "east", "direction_mismatch")
    require_equal(value.get("branch"), AUTHORED_BRANCH, "branch_binding_mismatch")
    require_equal(
        value.get("claimRevision"), CLAIM_REVISION, "claim_revision_mismatch"
    )
    require_equal(value.get("claimSha256"), CLAIM_SHA256, "claim_hash_mismatch")
    require_equal(
        value.get("publishedBase"), PUBLISHED_BASE, "published_base_mismatch"
    )
    require_equal(
        value.get("authorityDeclaredBase"),
        AUTHORITY_DECLARED_BASE,
        "authority_declared_base_mismatch",
    )
    require_equal(
        value.get("disposition"),
        "ZERO_CHILD_READINESS_ONLY",
        "disposition_mismatch",
    )

    bindings = require_object(value.get("bindings"), "bindings")
    require_equal(set(bindings), set(EXPECTED_BINDINGS), "binding_set_mismatch")
    validated_bindings = {}
    for name in sorted(EXPECTED_BINDINGS):
        validated, _payload = validate_binding(name, bindings.get(name))
        validated_bindings[name] = validated

    require_equal(value.get("futureSchedule"), MISSING_SCHEDULE, "schedule_must_be_missing")
    require_equal(
        value.get("futureAppearanceLock"),
        MISSING_FILE_BINDING,
        "appearance_lock_must_be_missing",
    )
    require_equal(
        value.get("futureSourceProductionProfile"),
        MISSING_FILE_BINDING,
        "source_profile_must_be_missing",
    )
    target = require_object(value.get("targetGrant"), "targetGrant")
    require_equal(
        target,
        {
            "direction": "east",
            "claim": "PLAY-079",
            "branch": AUTHORED_BRANCH,
            "claimRevision": CLAIM_REVISION,
            "claimSha256": CLAIM_SHA256,
            "baseCommit": PUBLISHED_BASE,
            "processes": ["A", "B", "C"],
            "maximumChildStartsPerProcess": 1,
            "orchestratorOnly": True,
            "directLowLevelInvocationAllowed": False,
        },
        "target_grant_mismatch",
    )
    require_equal(
        value.get("exclusiveRoots"), EXPECTED_EXCLUSIVE_ROOTS, "exclusive_roots_mismatch"
    )
    require_equal(
        value.get("processRoots"), EXPECTED_PROCESS_ROOTS, "process_roots_mismatch"
    )
    require_equal(
        value.get("queuePolicy"),
        {
            "requiredTokens": ["east:A", "east:B", "east:C"],
            "requiredRelativeOrder": ["east:A", "east:B", "east:C"],
        },
        "queue_policy_mismatch",
    )
    require_equal(value.get("readiness"), ZERO_READINESS, "zero_child_state_mismatch")
    require_equal(
        value.get("readinessPacket"), PACKET_RELATIVE, "readiness_packet_mismatch"
    )
    return {
        "status": "PASS_BLOCKED_ZERO_CHILD",
        "identity": branch_identity(),
        "bindings": validated_bindings,
        "target": target,
        "futureSchedule": MISSING_SCHEDULE,
        "futureAppearanceLock": MISSING_FILE_BINDING,
        "futureSourceProductionProfile": MISSING_FILE_BINDING,
        "exclusiveRoots": EXPECTED_EXCLUSIVE_ROOTS,
        "processRoots": EXPECTED_PROCESS_ROOTS,
        "readiness": ZERO_READINESS,
        "launchSurface": validate_no_launch_api(),
    }


def safe_integration_path(value: object, label: str) -> str:
    if not isinstance(value, str):
        reject("unsafe_schedule_path", f"{label}: not a string")
    try:
        HARDENED.safe_repo_relative(value, label)
    except HARDENED.ReplayRejected as error:
        raise AdapterRejected("unsafe_schedule_path", error.detail) from error
    if not value.startswith(INTEGRATION_PREFIX):
        reject("unsafe_schedule_path", f"{label}: outside Integration root")
    return value


def capture_schedule(
    path: str, commit: str, expected_sha256: str
) -> tuple[dict[str, Any], bytes, dict[str, str]]:
    relative = safe_integration_path(path, "schedule")
    if not isinstance(commit, str) or len(commit) != 40:
        reject("schedule_commit_invalid", commit)
    if not isinstance(expected_sha256, str) or len(expected_sha256) != 64:
        reject("schedule_hash_invalid", expected_sha256)
    git_is_ancestor(PUBLISHED_BASE, commit, "stale_schedule_commit")
    head = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=REPOSITORY_ROOT,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    git_is_ancestor(commit, head, "schedule_commit_not_in_branch")
    try:
        blob, tree = HARDENED.git_blob(commit, relative, "schedule")
        working = HARDENED.capture_repository_file(relative, "schedule")
    except HARDENED.ReplayRejected as error:
        raise AdapterRejected(error.code, error.detail) from error
    require_equal(sha256_bytes(blob), expected_sha256, "schedule_hash_mismatch")
    require_equal(working, blob, "schedule_working_bytes_mismatch")
    return load_json(blob, "schedule"), blob, {
        "path": relative,
        "commit": commit,
        "sha256": expected_sha256,
        "gitMode": tree["mode"],
        "gitObjectId": tree["objectId"],
    }


def require_schedule_binding_arguments(
    schedule: object, schedule_commit: object, schedule_sha256: object
) -> tuple[str, str, str]:
    missing = [
        name
        for name, value in (
            ("schedule", schedule),
            ("scheduleCommit", schedule_commit),
            ("scheduleSha256", schedule_sha256),
        )
        if not value
    ]
    if missing:
        reject("missing_schedule_binding", missing)
    return str(schedule), str(schedule_commit), str(schedule_sha256)


def validate_future_binding(
    value: object, label: str, schedule_commit: str
) -> dict[str, str]:
    binding = require_object(value, label)
    if set(binding) != {"path", "sha256"}:
        reject(f"{label}_binding_shape_invalid", binding)
    relative = safe_integration_path(binding.get("path"), label)
    expected_hash = binding.get("sha256")
    if not isinstance(expected_hash, str) or len(expected_hash) != 64:
        reject(f"{label}_hash_invalid", expected_hash)
    try:
        blob, tree = HARDENED.git_blob(schedule_commit, relative, label)
        working = HARDENED.capture_repository_file(relative, label)
    except HARDENED.ReplayRejected as error:
        raise AdapterRejected(error.code, error.detail) from error
    require_equal(
        sha256_bytes(blob), expected_hash, f"{label}_git_blob_hash_mismatch"
    )
    require_equal(
        sha256_bytes(working), expected_hash, f"{label}_working_hash_mismatch"
    )
    return {
        "path": relative,
        "sha256": expected_hash,
        "commit": schedule_commit,
        "gitMode": tree["mode"],
        "gitObjectId": tree["objectId"],
    }


def validate_east_schedule_fields(schedule: dict[str, Any]) -> dict[str, Any]:
    require_equal(schedule.get("phase"), "postlock_abc", "wrong_schedule_phase")
    if schedule.get("appearanceLock") is None:
        reject("appearance_lock_missing", "postlock_abc")
    if schedule.get("sourceProductionProfile") is None:
        reject("source_profile_missing", "postlock_abc")
    envelope = require_object(schedule.get("computeEnvelope"), "computeEnvelope")
    slots = envelope.get("slotIds")
    queue = envelope.get("queueOrder")
    if not isinstance(slots, list) or not slots:
        reject("slot_set_invalid", slots)
    if not isinstance(queue, list):
        reject("queue_invalid", queue)
    grants = schedule.get("directionGrants")
    if not isinstance(grants, list):
        reject("direction_grants_invalid", grants)
    east_grants = [
        item for item in grants if isinstance(item, dict) and item.get("direction") == "east"
    ]
    if len(east_grants) != 1:
        reject("east_grant_missing_or_duplicate", len(east_grants))
    east = east_grants[0]
    require_equal(east.get("claim"), "PLAY-079", "wrong_claim")
    require_equal(east.get("branch"), AUTHORED_BRANCH, "wrong_branch")
    require_equal(east.get("claimSha256"), CLAIM_SHA256, "wrong_claim_hash")
    require_equal(east.get("baseCommit"), PUBLISHED_BASE, "wrong_base")
    require_equal(
        east.get("orchestrator"),
        EXPECTED_BINDINGS["highLevelOrchestrator"],
        "wrong_orchestrator",
    )
    require_equal(
        east.get("exclusiveRoots"), EXPECTED_EXCLUSIVE_ROOTS, "wrong_exclusive_roots"
    )
    processes = east.get("processes")
    if not isinstance(processes, list) or len(processes) != 3:
        reject("wrong_process_set", processes)
    by_process = {
        item.get("process"): item for item in processes if isinstance(item, dict)
    }
    require_equal(set(by_process), set("ABC"), "wrong_process_set")
    for process in "ABC":
        grant = by_process[process]
        require_equal(grant.get("state"), "granted", f"process_{process}_not_granted")
        if grant.get("slotId") not in slots:
            reject("wrong_slot", f"{process}: {grant.get('slotId')}")
        require_equal(
            grant.get("maximumChildStarts"), 1, f"process_{process}_wrong_child_limit"
        )
        require_equal(
            grant.get("orchestratorOnly"), True, f"process_{process}_orchestrator_bypass"
        )
        require_equal(
            grant.get("directLowLevelInvocationAllowed"),
            False,
            f"process_{process}_direct_low_level_enabled",
        )
    required = ["east:A", "east:B", "east:C"]
    if any(token not in queue for token in required):
        reject("queue_missing_east_process", queue)
    positions = [queue.index(token) for token in required]
    if positions != sorted(positions):
        reject("wrong_east_queue_order", queue)
    return {
        "direction": "east",
        "phase": "postlock_abc",
        "processes": ["A", "B", "C"],
        "slots": {process: by_process[process]["slotId"] for process in "ABC"},
        "queuePositions": dict(zip(required, positions)),
        "exclusiveRoots": EXPECTED_EXCLUSIVE_ROOTS,
        "processRoots": EXPECTED_PROCESS_ROOTS,
        "maximumChildStartsPerProcess": 1,
        "directLowLevelInvocationAllowed": False,
        "childStartsPerformed": 0,
    }


def consume_schedule(
    contract: dict[str, Any],
    schedule_path: str,
    schedule_commit: str,
    schedule_sha256: str,
) -> dict[str, Any]:
    contract_result = validate_contract(contract)
    schedule, payload, binding = capture_schedule(
        schedule_path, schedule_commit, schedule_sha256
    )
    require_equal(
        schedule.get("integrationAuthorityCommit"),
        schedule_commit,
        "schedule_authority_commit_mismatch",
    )
    shared_path = (
        REPOSITORY_ROOT
        / EXPECTED_BINDINGS["scheduleSemanticValidator"]["path"]
    )
    shared_validator = load_module(shared_path, "citysim_shared_schedule_validator")
    schedule_absolute = REPOSITORY_ROOT / binding["path"]
    try:
        shared_result = shared_validator.validate(REPOSITORY_ROOT, schedule_absolute)
    except Exception as error:
        reject("shared_schedule_validation_failed", error)
    second_capture = HARDENED.capture_repository_file(binding["path"], "schedule")
    require_equal(second_capture, payload, "schedule_changed_during_semantic_validation")
    require_equal(shared_result.get("result"), "PASS", "shared_schedule_not_pass")
    require_equal(shared_result.get("phase"), "postlock_abc", "wrong_schedule_phase")
    east = validate_east_schedule_fields(schedule)
    appearance = validate_future_binding(
        schedule.get("appearanceLock"), "appearanceLock", schedule_commit
    )
    profile = validate_future_binding(
        schedule.get("sourceProductionProfile"),
        "sourceProductionProfile",
        schedule_commit,
    )
    return {
        "status": "VALIDATED_ZERO_CHILD_DELEGATION_PLAN",
        "schedule": binding,
        "sharedValidatorResult": shared_result,
        "eastGrant": east,
        "appearanceLock": appearance,
        "sourceProductionProfile": profile,
        "highLevelOrchestrator": contract_result["bindings"]["highLevelOrchestrator"],
        "launchPerformed": False,
        "childStarts": 0,
        "directLowLevelInvocationPossible": False,
    }


def synthetic_postlock_schedule() -> dict[str, Any]:
    processes = [
        {
            "grantId": f"east-{process.lower()}-synthetic",
            "process": process,
            "state": "granted",
            "slotId": f"dcc-{index}",
            "maximumChildStarts": 1,
            "orchestratorOnly": True,
            "directLowLevelInvocationAllowed": False,
        }
        for index, process in enumerate("ABC")
    ]
    return {
        "phase": "postlock_abc",
        "appearanceLock": {"path": f"{INTEGRATION_PREFIX}future-lock.json", "sha256": "1" * 64},
        "sourceProductionProfile": {
            "path": f"{INTEGRATION_PREFIX}future-profile.json",
            "sha256": "2" * 64,
        },
        "computeEnvelope": {
            "slotIds": ["dcc-0", "dcc-1", "dcc-2"],
            "queueOrder": ["north:B", "east:A", "east:B", "east:C", "north:C"],
        },
        "directionGrants": [
            {
                "direction": "east",
                "claim": "PLAY-079",
                "branch": AUTHORED_BRANCH,
                "claimSha256": CLAIM_SHA256,
                "baseCommit": PUBLISHED_BASE,
                "orchestrator": dict(EXPECTED_BINDINGS["highLevelOrchestrator"]),
                "exclusiveRoots": list(EXPECTED_EXCLUSIVE_ROOTS),
                "processes": processes,
            }
        ],
    }


def set_pointer(value: Any, pointer: tuple[object, ...], replacement: object) -> None:
    current = value
    for part in pointer[:-1]:
        current = current[part]
    current[pointer[-1]] = replacement


def adversarial_cases(contract: dict[str, Any]) -> list[dict[str, str]]:
    contract_cases = [
        (
            "wrong_claim_revision",
            ("claimRevision",),
            4,
            "claim_revision_mismatch",
        ),
        (
            "stale_published_base",
            ("publishedBase",),
            "0" * 40,
            "published_base_mismatch",
        ),
        (
            "stale_schema_hash",
            ("bindings", "scheduleSchema", "sha256"),
            "0" * 64,
            "scheduleSchema_hash_mismatch",
        ),
    ]
    schedule_cases = [
        ("wrong_phase", ("phase",), "prelock_north_a", "wrong_schedule_phase"),
        (
            "wrong_direction",
            ("directionGrants", 0, "direction"),
            "south",
            "east_grant_missing_or_duplicate",
        ),
        (
            "wrong_claim_hash",
            ("directionGrants", 0, "claimSha256"),
            "0" * 64,
            "wrong_claim_hash",
        ),
        (
            "wrong_base",
            ("directionGrants", 0, "baseCommit"),
            "0" * 40,
            "wrong_base",
        ),
        (
            "wrong_slot",
            ("directionGrants", 0, "processes", 0, "slotId"),
            "dcc-foreign",
            "wrong_slot",
        ),
        (
            "wrong_queue",
            ("computeEnvelope", "queueOrder"),
            ["east:B", "east:A", "east:C"],
            "wrong_east_queue_order",
        ),
        (
            "wrong_roots",
            ("directionGrants", 0, "exclusiveRoots"),
            [
                EXPECTED_EXCLUSIVE_ROOTS[0],
                "docs/production/evidence/PLAY-080/industrial-l04-south-source-v01/",
            ],
            "wrong_exclusive_roots",
        ),
        (
            "wrong_orchestrator",
            ("directionGrants", 0, "orchestrator", "sha256"),
            "0" * 64,
            "wrong_orchestrator",
        ),
        (
            "appearance_lock_missing",
            ("appearanceLock",),
            None,
            "appearance_lock_missing",
        ),
        (
            "source_profile_missing",
            ("sourceProductionProfile",),
            None,
            "source_profile_missing",
        ),
        (
            "wrong_child_limit",
            ("directionGrants", 0, "processes", 1, "maximumChildStarts"),
            2,
            "process_B_wrong_child_limit",
        ),
        (
            "orchestrator_bypass",
            ("directionGrants", 0, "processes", 2, "orchestratorOnly"),
            False,
            "process_C_orchestrator_bypass",
        ),
        (
            "direct_low_level_enabled",
            (
                "directionGrants",
                0,
                "processes",
                0,
                "directLowLevelInvocationAllowed",
            ),
            True,
            "process_A_direct_low_level_enabled",
        ),
    ]
    results = []
    for name, pointer, replacement, expected_code in contract_cases:
        mutated = copy.deepcopy(contract)
        set_pointer(mutated, pointer, replacement)
        try:
            validate_contract(mutated)
        except AdapterRejected as error:
            require_equal(error.code, expected_code, f"{name}_wrong_rejection")
            results.append({"case": name, "result": "REJECTED", "code": error.code})
        else:
            reject("adversary_accepted", name)
    for name, pointer, replacement, expected_code in schedule_cases:
        mutated = synthetic_postlock_schedule()
        set_pointer(mutated, pointer, replacement)
        try:
            validate_east_schedule_fields(mutated)
        except AdapterRejected as error:
            require_equal(error.code, expected_code, f"{name}_wrong_rejection")
            results.append({"case": name, "result": "REJECTED", "code": error.code})
        else:
            reject("adversary_accepted", name)
    try:
        require_schedule_binding_arguments(None, None, None)
    except AdapterRejected as error:
        require_equal(
            error.code, "missing_schedule_binding", "missing_schedule_wrong_rejection"
        )
        results.append(
            {
                "case": "missing_schedule",
                "result": "REJECTED",
                "code": error.code,
            }
        )
    else:
        reject("adversary_accepted", "missing_schedule")
    try:
        capture_schedule(
            EXPECTED_BINDINGS["adapterAuthority"]["path"],
            PUBLISHED_BASE,
            "0" * 64,
        )
    except AdapterRejected as error:
        require_equal(
            error.code, "schedule_hash_mismatch", "stale_schedule_wrong_rejection"
        )
        results.append(
            {
                "case": "stale_schedule_hash",
                "result": "REJECTED",
                "code": error.code,
            }
        )
    else:
        reject("adversary_accepted", "stale_schedule_hash")
    return results


def validate_implementation(commit: str) -> dict[str, dict[str, str]]:
    if not isinstance(commit, str) or len(commit) != 40:
        reject("implementation_commit_invalid", commit)
    git_is_ancestor(PUBLISHED_BASE, commit, "implementation_not_descendant")
    result = {}
    for label, relative in (
        ("contract", CONTRACT_RELATIVE),
        ("adapter", ADAPTER_RELATIVE),
        ("tests", TEST_RELATIVE),
    ):
        try:
            blob, tree = HARDENED.git_blob(commit, relative, f"implementation.{label}")
            working = HARDENED.capture_repository_file(relative, f"implementation.{label}")
        except HARDENED.ReplayRejected as error:
            raise AdapterRejected(error.code, error.detail) from error
        require_equal(
            sha256_bytes(working),
            sha256_bytes(blob),
            f"implementation_{label}_working_mismatch",
        )
        result[label] = {
            "path": relative,
            "sha256": sha256_bytes(blob),
            "commit": commit,
            "gitMode": tree["mode"],
            "gitObjectId": tree["objectId"],
        }
    return result


def build_readiness_packet(
    contract: dict[str, Any], implementation_commit: str
) -> dict[str, Any]:
    first = validate_contract(contract)
    second = validate_contract(contract)
    first_bytes = canonical_bytes(first)
    second_bytes = canonical_bytes(second)
    require_equal(first_bytes, second_bytes, "repeat_validation_byte_mismatch")
    cases = adversarial_cases(contract)
    return {
        "schema": "citysim.play-079.east-zero-child-schedule-readiness.v1",
        "schemaVersion": 1,
        "taskId": "PLAY-079",
        "direction": "east",
        "branch": AUTHORED_BRANCH,
        "status": "BLOCKED_AWAITING_VALID_POSTLOCK_SCHEDULE",
        "publishedBase": PUBLISHED_BASE,
        "claimRevision": CLAIM_REVISION,
        "claimSha256": CLAIM_SHA256,
        "implementation": validate_implementation(implementation_commit),
        "bindings": first["bindings"],
        "targetFutureGrants": ["east:A", "east:B", "east:C"],
        "futureSchedule": MISSING_SCHEDULE,
        "appearanceLock": MISSING_FILE_BINDING,
        "sourceProductionProfile": MISSING_FILE_BINDING,
        "repeatValidation": {
            "runs": 2,
            "byteIdentical": True,
            "runSha256": [sha256_bytes(first_bytes), sha256_bytes(second_bytes)],
        },
        "adversarialCases": cases,
        "adversarialRejectedCount": len(cases),
        "launchSurface": first["launchSurface"],
        "readiness": ZERO_READINESS,
        "invocationCounts": {
            "adapterChildStarts": 0,
            "highLevelOrchestratorStarts": 0,
            "lowLevelRunnerStarts": 0,
            "blender": 0,
            "dcc": 0,
            "render": 0,
            "normalizer": 0,
            "sourceA": 0,
            "sourceB": 0,
            "sourceC": 0,
        },
        "pixelFiles": [],
    }


def validate_packet(
    packet: dict[str, Any], evidence_commit: str
) -> dict[str, str]:
    expected = canonical_bytes(packet)
    try:
        blob, tree = HARDENED.git_blob(
            evidence_commit, PACKET_RELATIVE, "zeroChildReadiness"
        )
        working = HARDENED.capture_repository_file(
            PACKET_RELATIVE, "zeroChildReadiness"
        )
    except HARDENED.ReplayRejected as error:
        raise AdapterRejected(error.code, error.detail) from error
    require_equal(blob, expected, "readiness_packet_blob_mismatch")
    require_equal(working, expected, "readiness_packet_working_mismatch")
    return {
        "path": PACKET_RELATIVE,
        "commit": evidence_commit,
        "sha256": sha256_bytes(blob),
        "gitMode": tree["mode"],
        "gitObjectId": tree["objectId"],
    }


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--mode",
        choices=("readiness", "self-test", "consume", "packet", "verify-packet"),
        default="readiness",
    )
    parser.add_argument("--schedule")
    parser.add_argument("--schedule-commit")
    parser.add_argument("--schedule-sha256")
    parser.add_argument("--implementation-commit")
    parser.add_argument("--evidence-commit")
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    try:
        contract = load_json(
            HARDENED.capture_repository_file(CONTRACT_RELATIVE, "adapterContract"),
            "adapterContract",
        )
        if arguments.mode == "readiness":
            output: object = validate_contract(contract)
        elif arguments.mode == "self-test":
            output = {
                "status": "PASS_ZERO_CHILD",
                "cases": adversarial_cases(contract),
                "launchSurface": validate_no_launch_api(),
                "childStarts": 0,
            }
        elif arguments.mode == "consume":
            schedule, schedule_commit, schedule_sha256 = (
                require_schedule_binding_arguments(
                    arguments.schedule,
                    arguments.schedule_commit,
                    arguments.schedule_sha256,
                )
            )
            output = consume_schedule(
                contract,
                schedule,
                schedule_commit,
                schedule_sha256,
            )
        else:
            if not arguments.implementation_commit:
                reject("implementation_commit_required", arguments.mode)
            packet = build_readiness_packet(contract, arguments.implementation_commit)
            if arguments.mode == "packet":
                output = packet
            else:
                if not arguments.evidence_commit:
                    reject("evidence_commit_required", arguments.mode)
                output = {
                    "status": "PASS",
                    "packet": validate_packet(packet, arguments.evidence_commit),
                }
        sys.stdout.buffer.write(canonical_bytes(output))
        return 0
    except (AdapterRejected, HARDENED.ReplayRejected) as error:
        sys.stderr.buffer.write(
            canonical_bytes(
                {
                    "status": "REJECTED_ZERO_CHILD",
                    "stage": "before_orchestrator_or_dcc",
                    "code": error.code,
                    "detail": error.detail,
                    "childStarts": 0,
                    "blenderInvocations": 0,
                    "dccInvocations": 0,
                    "renderInvocations": 0,
                    "pixelFilesCreated": 0,
                }
            )
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
