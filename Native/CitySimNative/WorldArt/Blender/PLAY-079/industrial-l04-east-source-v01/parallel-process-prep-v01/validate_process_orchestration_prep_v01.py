#!/usr/bin/env python3
"""Validate PLAY-079 East A/B/C orchestration preparation without launching work."""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import pathlib
import subprocess
import sys
from typing import Any, Callable, NoReturn


VERSION_ROOT = pathlib.Path(__file__).resolve().parent
SOURCE_ROOT = VERSION_ROOT.parent
REPOSITORY_ROOT = VERSION_ROOT.parents[6]
CONTRACT_RELATIVE = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
    "industrial-l04-east-source-v01/parallel-process-prep-v01/"
    "PROCESS-ORCHESTRATION-PREP-CONTRACT.json"
)
VALIDATOR_RELATIVE = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
    "industrial-l04-east-source-v01/parallel-process-prep-v01/"
    "validate_process_orchestration_prep_v01.py"
)
TEST_RELATIVE = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
    "industrial-l04-east-source-v01/parallel-process-prep-v01/"
    "test_process_orchestration_prep_v01.py"
)
EVIDENCE_RELATIVE = (
    "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/"
    "parallel-process-prep-v01/VALIDATION.json"
)
INTEGRATION_MASTER = "69b62e78f6012115d5d1221cea3a34e26cae5683"
AUTHORED_BRANCH = "codex/citysim-world-art-east"
ALLOWED_REPLAY_BRANCHES = {AUTHORED_BRANCH, "master"}
EAST_EVIDENCE_ROOT = (
    "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/"
)
PIXEL_SUFFIXES = {
    ".bmp",
    ".exr",
    ".gif",
    ".jpeg",
    ".jpg",
    ".png",
    ".tif",
    ".tiff",
    ".webp",
}


class PrepRejected(RuntimeError):
    """Stable fail-closed preparation rejection."""

    def __init__(self, code: str, detail: object):
        super().__init__(str(detail))
        self.code = code
        self.detail = str(detail)


def reject(code: str, detail: object) -> NoReturn:
    raise PrepRejected(code, detail)


def canonical_bytes(value: object) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
        + "\n"
    ).encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def load_hardened_module() -> Any:
    path = SOURCE_ROOT / "replay_current_master_inputs.py"
    spec = importlib.util.spec_from_file_location("play079_replay_capture", path)
    if spec is None or spec.loader is None:
        reject("hardened_capture_import_failed", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


HARDENED = load_hardened_module()


EXPECTED_BINDINGS = {
    "claim": {
        "path": "docs/production/claims/PLAY-079.world-art-east.md",
        "sha256": "5439d720e0a4c90e7310a7fd94ad1a94dd18497df4ef048de726e33405670fab",
    },
    "runner": {
        "path": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
            "industrial-l04-east-source-v01/RUNNER-CONTRACT.json"
        ),
        "sha256": "5302750257a0bc158f6b460f78a48dccd22c2194f169deb8e46e5c61f1204da8",
    },
    "existingOrchestrator": {
        "path": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
            "industrial-l04-east-source-v01/orchestrate_parallel_source.py"
        ),
        "sha256": "50045214378cf19c10fda0b1da6b74be496201b8bae4e961b4ee3210a63d530c",
    },
    "outputSafety": {
        "path": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
            "industrial-l04-east-source-v01/east_output_safety.py"
        ),
        "sha256": "a4d316d0b40ca16b714f12740c3a840ac140dda1dec5d322bee275b56fa5c458",
    },
    "prelockSuccessorContract": {
        "path": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
            "industrial-l04-east-source-v01/prelock-successor-v01/"
            "SUCCESSOR-CONTRACT.json"
        ),
        "sha256": "9c07f6e969916ff225ca745cbc07c0d7a8a5e442f683faea5b486e7b6b2cb200",
    },
    "prelockSuccessorValidator": {
        "path": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
            "industrial-l04-east-source-v01/prelock-successor-v01/"
            "validate_prelock_successor_v01.py"
        ),
        "sha256": "95c676be0f366c29114e01839ceb496eafaeabec55ab10e57f0e523053b69305",
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
    "parallelExecutionDesign": {
        "path": (
            "docs/production/evidence/INTEGRATION/"
            "INDUSTRIAL-L04-PARALLEL-EXECUTION-CONTRACT-CANDIDATE.md"
        ),
        "sha256": "a2c726585fa83f9a795c02cb4e97fd476ae3969587db7c5e133ecc9889636e36",
    },
    "sourceStageSchema": {
        "path": (
            "docs/production/evidence/INTEGRATION/"
            "industrial-l04-source-stage-handoff-schema-v2.json"
        ),
        "sha256": "93efe9ca6d000a2d145098f722338c8e85829d6de6724c3f231a93c06eadf3d7",
    },
    "sourceStageSemanticValidator": {
        "path": (
            "Native/CitySimNative/WorldArt/Shared/"
            "validate_source_stage_handoff_v2.py"
        ),
        "sha256": "7a0613af9998a222a583a70930ce3afc5ec1902793f03201f899a2bb4129f340",
    },
}

MISSING_AUTHORITY = {
    "state": "missing",
    "path": None,
    "commit": None,
    "sha256": None,
}
EXPECTED_FUTURE_AUTHORITIES = {
    name: MISSING_AUTHORITY
    for name in (
        "appearanceLock",
        "sourceProductionProfile",
        "strictReceiptSchema",
        "strictReceiptValidator",
        "globalScheduleSchema",
        "globalSchedule",
        "computeEnvelope",
        "launchGrant",
    )
}
EXPECTED_GATES = {
    "launchAllowed": False,
    "dccAllowed": False,
    "renderAllowed": False,
    "pixelProductionAllowed": False,
    "normalizationAllowed": False,
    "packetAssemblyAllowed": False,
    "sourceReady": False,
    "integrationAdmitted": False,
    "productionSelected": False,
}
EXPECTED_SAFETY = {
    "siblingInputs": [],
    "sharedWrites": [],
    "subprocessInvocations": 0,
    "dccInvocations": 0,
    "blenderInvocations": 0,
    "renderApiCalls": 0,
    "pixelFilesCreated": 0,
    "normalizerInvocations": 0,
    "sourcePacketsCreated": 0,
}


def process_roots(process_id: str) -> dict[str, object]:
    lower = process_id.lower()
    return {
        "state": "reserved_not_launched",
        "invocationCount": 0,
        "rawRoot": f"{EAST_EVIDENCE_ROOT}renders/process-{lower}/",
        "evidenceRoot": f"{EAST_EVIDENCE_ROOT}execution/process-{lower}/",
        "invocationReceipt": (
            f"{EAST_EVIDENCE_ROOT}execution/process-{lower}/"
            "INVOCATION-RECEIPT.json"
        ),
    }


def job_record(
    identifier: str, kind: str, dependencies: list[str], suffix: str
) -> dict[str, object]:
    return {
        "id": identifier,
        "kind": kind,
        "dependsOn": dependencies,
        "root": f"{EAST_EVIDENCE_ROOT}{suffix}",
    }


def expected_jobs() -> list[dict[str, object]]:
    jobs = [
        job_record(f"raw-{process}", "reserved-process", [], f"renders/process-{process.lower()}/")
        for process in "ABC"
    ]
    jobs.extend(
        job_record(
            f"provenance-rgba-{process}",
            "validation",
            [f"raw-{process}"],
            f"execution/validation-jobs/provenance-rgba-{process.lower()}/",
        )
        for process in "ABC"
    )
    jobs.append(
        job_record(
            "identity-join",
            "join",
            [f"provenance-rgba-{process}" for process in "ABC"],
            "execution/validation-jobs/identity-join/",
        )
    )
    jobs.extend(
        job_record(
            f"normalization-repeat-{process}",
            "reserved-validation",
            ["identity-join"],
            f"execution/validation-jobs/normalization-repeat-{process.lower()}/",
        )
        for process in "ABC"
    )
    for family in ("literal-color", "grayscale", "contact-sheet"):
        jobs.extend(
            job_record(
                f"{family}-{process}",
                "reserved-validation",
                [f"normalization-repeat-{process}"],
                f"execution/validation-jobs/{family}-{process.lower()}/",
            )
            for process in "ABC"
        )
    jobs.append(
        job_record(
            "packet-assembly",
            "single-assembler",
            [
                f"{family}-{process}"
                for family in ("literal-color", "grayscale", "contact-sheet")
                for process in "ABC"
            ],
            "execution/packet-assembly/",
        )
    )
    return jobs


EXPECTED_ASSEMBLER = {
    "jobId": "packet-assembly",
    "invocationCount": 0,
    "packetPath": f"{EAST_EVIDENCE_ROOT}SOURCE-STAGE-HANDOFF.json",
    "packetExists": False,
}


def require_object(value: object, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        reject("contract_shape_invalid", f"{label}: expected object")
    return value


def load_json(payload: bytes, label: str) -> dict[str, Any]:
    try:
        value = json.loads(payload)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise PrepRejected(f"{label}_json_invalid", error) from error
    return require_object(value, label)


def require_equal(actual: object, expected: object, code: str) -> None:
    if actual != expected:
        reject(code, f"{actual!r} != {expected!r}")


def branch_and_ancestry() -> dict[str, object]:
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
    ancestor = subprocess.run(
        ["git", "merge-base", "--is-ancestor", INTEGRATION_MASTER, head],
        cwd=REPOSITORY_ROOT,
        check=False,
        capture_output=True,
    )
    if ancestor.returncode:
        reject("integration_master_not_ancestor", f"{INTEGRATION_MASTER} !<= {head}")
    return {
        "authoredBranch": AUTHORED_BRANCH,
        "replayBranch": branch,
        "integrationMaster": INTEGRATION_MASTER,
        "integrationMasterAncestorOfReplayHead": True,
    }


def validate_binding(
    name: str, declared: object
) -> tuple[dict[str, str], bytes]:
    expected = EXPECTED_BINDINGS[name]
    binding = require_object(declared, f"bindings.{name}")
    require_equal(binding.get("path"), expected["path"], f"{name}_path_mismatch")
    require_equal(binding.get("sha256"), expected["sha256"], f"{name}_hash_mismatch")
    try:
        blob, tree = HARDENED.git_blob(
            INTEGRATION_MASTER, expected["path"], f"processPrep.{name}"
        )
        working = HARDENED.capture_repository_file(
            expected["path"], f"processPrep.{name}"
        )
    except HARDENED.ReplayRejected as error:
        raise PrepRejected(error.code, error.detail) from error
    require_equal(
        sha256_bytes(blob), expected["sha256"], f"{name}_git_blob_hash_mismatch"
    )
    require_equal(
        sha256_bytes(working), expected["sha256"], f"{name}_working_hash_mismatch"
    )
    return {
        "path": expected["path"],
        "sha256": expected["sha256"],
        "authorityCommit": INTEGRATION_MASTER,
        "gitMode": tree["mode"],
        "gitObjectId": tree["objectId"],
    }, working


def safe_east_path(value: object, label: str) -> str:
    if not isinstance(value, str):
        reject("unsafe_east_path", f"{label}: not a string")
    try:
        HARDENED.safe_repo_relative(value, label)
    except HARDENED.ReplayRejected as error:
        raise PrepRejected("unsafe_east_path", error.detail) from error
    if not value.startswith(EAST_EVIDENCE_ROOT):
        reject("unsafe_east_path", f"{label}: outside East root")
    for forbidden in ("/PLAY-027/", "/PLAY-080/", "/PLAY-081/", "/INTEGRATION/", "/Shared/"):
        if forbidden in f"/{value}":
            reject("unsafe_east_path", f"{label}: forbidden {forbidden}")
    return value


def roots_overlap(left: str, right: str) -> bool:
    left_path = pathlib.PurePosixPath(left.rstrip("/"))
    right_path = pathlib.PurePosixPath(right.rstrip("/"))
    return (
        left_path == right_path
        or left_path in right_path.parents
        or right_path in left_path.parents
    )


def validate_root_isolation(
    processes: dict[str, Any], jobs: list[dict[str, Any]]
) -> list[str]:
    roots: list[tuple[str, str]] = []
    for process_id in "ABC":
        process = require_object(processes.get(process_id), f"processes.{process_id}")
        for field in ("rawRoot", "evidenceRoot"):
            roots.append(
                (
                    f"processes.{process_id}.{field}",
                    safe_east_path(process.get(field), f"processes.{process_id}.{field}"),
                )
            )
    for job in jobs:
        roots.append(
            (
                f"jobs.{job.get('id')}.root",
                safe_east_path(job.get("root"), f"jobs.{job.get('id')}.root"),
            )
        )
    unique: list[str] = []
    for index, (left_name, left) in enumerate(roots):
        for right_name, right in roots[index + 1 :]:
            if left == right:
                if {
                    left_name,
                    right_name,
                } in (
                    {"processes.A.rawRoot", "jobs.raw-A.root"},
                    {"processes.B.rawRoot", "jobs.raw-B.root"},
                    {"processes.C.rawRoot", "jobs.raw-C.root"},
                ):
                    continue
                reject(
                    "reserved_root_alias",
                    f"{left_name} aliases {right_name}: {left}",
                )
            if roots_overlap(left, right):
                reject(
                    "reserved_root_overlap",
                    f"{left_name} overlaps {right_name}: {left} / {right}",
                )
        if left not in unique:
            unique.append(left)
    return sorted(unique)


def validate_dag(jobs: list[dict[str, Any]]) -> dict[str, object]:
    identifiers = [job.get("id") for job in jobs]
    if len(identifiers) != len(set(identifiers)):
        reject("duplicate_job_id", identifiers)
    assemblers = [job for job in jobs if job.get("kind") == "single-assembler"]
    if len(assemblers) != 1 or assemblers[0].get("id") != "packet-assembly":
        reject("single_assembler_mismatch", assemblers)
    known = set(identifiers)
    dependencies = {
        str(job["id"]): list(job.get("dependsOn", []))
        for job in jobs
    }
    for identifier, required in dependencies.items():
        if any(item not in known for item in required):
            reject("unknown_job_dependency", f"{identifier}: {required}")
    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(identifier: str) -> None:
        if identifier in visiting:
            reject("job_cycle", identifier)
        if identifier in visited:
            return
        visiting.add(identifier)
        for dependency in dependencies[identifier]:
            visit(dependency)
        visiting.remove(identifier)
        visited.add(identifier)

    for identifier in identifiers:
        visit(str(identifier))
    require_equal(jobs, expected_jobs(), "dependency_graph_mismatch")
    return {
        "jobCount": len(jobs),
        "singleAssembler": "packet-assembly",
        "acyclic": True,
        "rawFanOut": ["raw-A", "raw-B", "raw-C"],
        "identityJoin": "identity-join",
        "packetAssembly": "packet-assembly",
    }


def pixel_inventory() -> list[str]:
    roots = (
        VERSION_ROOT,
        REPOSITORY_ROOT
        / "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/"
        "parallel-process-prep-v01",
    )
    return sorted(
        str(path.relative_to(REPOSITORY_ROOT))
        for root in roots
        if root.exists()
        for path in root.rglob("*")
        if path.is_file() and path.suffix.lower() in PIXEL_SUFFIXES
    )


def validate_contract(value: dict[str, Any]) -> dict[str, Any]:
    require_equal(
        value.get("schema"),
        "citysim.play-079.east-process-orchestration-prep.v1",
        "schema_mismatch",
    )
    require_equal(value.get("schemaVersion"), 1, "schema_version_mismatch")
    require_equal(value.get("taskId"), "PLAY-079", "task_mismatch")
    require_equal(value.get("direction"), "east", "direction_mismatch")
    require_equal(value.get("branch"), AUTHORED_BRANCH, "branch_binding_mismatch")
    require_equal(
        value.get("integrationMaster"),
        INTEGRATION_MASTER,
        "integration_master_mismatch",
    )
    require_equal(
        value.get("disposition"),
        "ZERO_PIXEL_NONPRODUCTION_PREPARATION",
        "disposition_mismatch",
    )

    future = require_object(
        value.get("futureIntegrationAuthorities"), "futureIntegrationAuthorities"
    )
    require_equal(set(future), set(EXPECTED_FUTURE_AUTHORITIES), "future_authority_set_mismatch")
    for name, expected in EXPECTED_FUTURE_AUTHORITIES.items():
        require_equal(future.get(name), expected, f"{name}_must_be_missing")
    require_equal(value.get("gates"), EXPECTED_GATES, "closed_gates_mismatch")
    require_equal(value.get("safety"), EXPECTED_SAFETY, "safety_boundary_open")

    bindings = require_object(value.get("bindings"), "bindings")
    require_equal(set(bindings), set(EXPECTED_BINDINGS), "binding_set_mismatch")
    validated_bindings: dict[str, dict[str, str]] = {}
    payloads: dict[str, bytes] = {}
    for name in sorted(EXPECTED_BINDINGS):
        validated, payload = validate_binding(name, bindings.get(name))
        validated_bindings[name] = validated
        payloads[name] = payload

    processes = require_object(value.get("processes"), "processes")
    require_equal(set(processes), set("ABC"), "process_set_mismatch")
    for process_id in "ABC":
        process = require_object(processes.get(process_id), f"processes.{process_id}")
        for field in ("rawRoot", "evidenceRoot", "invocationReceipt"):
            safe_east_path(process.get(field), f"processes.{process_id}.{field}")
        if process.get("invocationCount") != 0:
            reject("process_invocation_count_nonzero", process_id)
        require_equal(process, process_roots(process_id), "process_root_mismatch")

    jobs_value = value.get("jobs")
    if not isinstance(jobs_value, list) or not all(
        isinstance(job, dict) for job in jobs_value
    ):
        reject("jobs_shape_invalid", jobs_value)
    jobs = [dict(job) for job in jobs_value]
    dag = validate_dag(jobs)
    isolated_roots = validate_root_isolation(processes, jobs)

    assembler = require_object(value.get("singleAssembler"), "singleAssembler")
    safe_east_path(assembler.get("packetPath"), "singleAssembler.packetPath")
    if assembler.get("invocationCount") != 0:
        reject("assembler_invocation_count_nonzero", assembler)
    if assembler.get("packetExists") is not False:
        reject("packet_already_exists", assembler)
    require_equal(assembler, EXPECTED_ASSEMBLER, "assembler_binding_mismatch")
    packet_path = REPOSITORY_ROOT / EXPECTED_ASSEMBLER["packetPath"]
    if packet_path.exists() or packet_path.is_symlink():
        reject("reserved_packet_present", EXPECTED_ASSEMBLER["packetPath"])

    runner = load_json(payloads["runner"], "runner")
    require_equal(runner.get("sourceReady"), False, "runner_source_ready_open")
    require_equal(
        runner.get("sourceStage", {}).get("appearanceAuthority", {}).get("state"),
        "missing",
        "runner_appearance_authority_present",
    )
    require_equal(
        runner.get("sourceStage", {}).get("sourceProductionProfile"),
        MISSING_AUTHORITY,
        "runner_source_profile_present",
    )
    scene = load_json(payloads["scene"], "scene")
    materials = load_json(payloads["materials"], "materials")
    require_equal(scene.get("direction"), "east", "scene_direction_mismatch")
    require_equal(
        scene.get("orientationTransform"), "none", "scene_transform_mismatch"
    )
    require_equal(materials.get("direction"), "east", "materials_direction_mismatch")
    require_equal(
        materials.get("pixelRenderingAllowed"), False, "materials_pixel_gate_open"
    )

    pixels = pixel_inventory()
    if pixels:
        reject("pixel_file_present", pixels)
    return {
        "status": "PASS_ZERO_PIXEL_NONPRODUCTION_PREPARATION",
        "identity": branch_and_ancestry(),
        "bindings": validated_bindings,
        "futureIntegrationAuthorities": EXPECTED_FUTURE_AUTHORITIES,
        "gates": EXPECTED_GATES,
        "processes": processes,
        "dependencyGraph": dag,
        "reservedRootCount": len(isolated_roots),
        "reservedRoots": isolated_roots,
        "singleAssembler": EXPECTED_ASSEMBLER,
        "safety": EXPECTED_SAFETY,
        "pixelFiles": pixels,
    }


def set_pointer(value: dict[str, Any], pointer: tuple[object, ...], replacement: object) -> None:
    current: Any = value
    for part in pointer[:-1]:
        current = current[part]
    current[pointer[-1]] = replacement


def adversarial_cases(contract: dict[str, Any]) -> list[dict[str, str]]:
    cases: list[
        tuple[str, tuple[object, ...], object, str]
    ] = [
        (
            "stale_integration_master",
            ("integrationMaster",),
            "0" * 40,
            "integration_master_mismatch",
        ),
        (
            "appearance_lock_injected",
            ("futureIntegrationAuthorities", "appearanceLock", "state"),
            "present",
            "appearanceLock_must_be_missing",
        ),
        (
            "source_profile_injected",
            ("futureIntegrationAuthorities", "sourceProductionProfile", "state"),
            "present",
            "sourceProductionProfile_must_be_missing",
        ),
        (
            "stale_runner",
            ("bindings", "runner", "sha256"),
            "0" * 64,
            "runner_hash_mismatch",
        ),
        (
            "sibling_process_root",
            ("processes", "A", "rawRoot"),
            "docs/production/evidence/PLAY-080/industrial-l04-south-source-v01/renders/process-a/",
            "unsafe_east_path",
        ),
        (
            "shared_process_root",
            ("processes", "B", "evidenceRoot"),
            "docs/production/evidence/INTEGRATION/process-b/",
            "unsafe_east_path",
        ),
        (
            "unsafe_traversal",
            ("processes", "C", "rawRoot"),
            f"{EAST_EVIDENCE_ROOT}../PLAY-081/renders/process-c/",
            "unsafe_east_path",
        ),
        (
            "aliased_process_root",
            ("processes", "B", "rawRoot"),
            process_roots("A")["rawRoot"],
            "process_root_mismatch",
        ),
        (
            "job_cycle",
            ("jobs", 0, "dependsOn"),
            ["packet-assembly"],
            "job_cycle",
        ),
        (
            "second_assembler",
            ("jobs", 6, "kind"),
            "single-assembler",
            "single_assembler_mismatch",
        ),
        (
            "process_invoked",
            ("processes", "A", "invocationCount"),
            1,
            "process_invocation_count_nonzero",
        ),
        (
            "packet_claimed_present",
            ("singleAssembler", "packetExists"),
            True,
            "packet_already_exists",
        ),
        (
            "dcc_gate_open",
            ("gates", "dccAllowed"),
            True,
            "closed_gates_mismatch",
        ),
        (
            "dcc_invocation_claimed",
            ("safety", "dccInvocations"),
            1,
            "safety_boundary_open",
        ),
    ]
    results = []
    for name, pointer, replacement, expected_code in cases:
        mutated = copy.deepcopy(contract)
        set_pointer(mutated, pointer, replacement)
        try:
            validate_contract(mutated)
        except PrepRejected as error:
            require_equal(error.code, expected_code, f"{name}_wrong_rejection")
            results.append({"case": name, "result": "REJECTED", "code": error.code})
        else:
            reject("adversary_accepted", name)
    return results


def validate_implementation(commit: str) -> dict[str, dict[str, str]]:
    if not isinstance(commit, str) or len(commit) != 40:
        reject("implementation_commit_invalid", commit)
    ancestor = subprocess.run(
        ["git", "merge-base", "--is-ancestor", INTEGRATION_MASTER, commit],
        cwd=REPOSITORY_ROOT,
        check=False,
        capture_output=True,
    )
    if ancestor.returncode:
        reject("implementation_not_descendant", commit)
    result = {}
    for label, relative in (
        ("contract", CONTRACT_RELATIVE),
        ("validator", VALIDATOR_RELATIVE),
        ("tests", TEST_RELATIVE),
    ):
        try:
            blob, tree = HARDENED.git_blob(commit, relative, f"implementation.{label}")
            working = HARDENED.capture_repository_file(relative, f"implementation.{label}")
        except HARDENED.ReplayRejected as error:
            raise PrepRejected(error.code, error.detail) from error
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


def build_evidence(contract: dict[str, Any], implementation_commit: str) -> dict[str, Any]:
    first = validate_contract(contract)
    second = validate_contract(contract)
    first_bytes = canonical_bytes(first)
    second_bytes = canonical_bytes(second)
    require_equal(first_bytes, second_bytes, "repeat_validation_byte_mismatch")
    negatives = adversarial_cases(contract)
    return {
        "schema": "citysim.play-079.east-process-orchestration-prep-validation.v1",
        "schemaVersion": 1,
        "taskId": "PLAY-079",
        "direction": "east",
        "status": "PASS_ZERO_PIXEL_NONPRODUCTION_PREPARATION",
        "integrationMaster": INTEGRATION_MASTER,
        "implementation": validate_implementation(implementation_commit),
        "repeatValidation": {
            "runs": 2,
            "byteIdentical": True,
            "runSha256": [sha256_bytes(first_bytes), sha256_bytes(second_bytes)],
        },
        "adversarialCases": negatives,
        "adversarialRejectedCount": len(negatives),
        "futureIntegrationAuthorities": EXPECTED_FUTURE_AUTHORITIES,
        "sourceReady": False,
        "production": False,
        "singleAssemblerInvocations": 0,
        "invocationCounts": {
            "subprocess": 0,
            "dcc": 0,
            "blender": 0,
            "renderApi": 0,
            "normalizer": 0,
            "sourceA": 0,
            "sourceB": 0,
            "sourceC": 0,
            "packetAssembler": 0,
        },
        "pixelFiles": [],
        "sourcePacketsCreated": 0,
    }


def validate_evidence(
    evidence: dict[str, Any], evidence_commit: str
) -> dict[str, str]:
    expected = canonical_bytes(evidence)
    try:
        blob, tree = HARDENED.git_blob(
            evidence_commit, EVIDENCE_RELATIVE, "orchestrationPrepEvidence"
        )
        working = HARDENED.capture_repository_file(
            EVIDENCE_RELATIVE, "orchestrationPrepEvidence"
        )
    except HARDENED.ReplayRejected as error:
        raise PrepRejected(error.code, error.detail) from error
    require_equal(blob, expected, "evidence_blob_content_mismatch")
    require_equal(working, expected, "evidence_working_content_mismatch")
    return {
        "path": EVIDENCE_RELATIVE,
        "sha256": sha256_bytes(blob),
        "commit": evidence_commit,
        "gitMode": tree["mode"],
        "gitObjectId": tree["objectId"],
    }


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--mode",
        choices=("validate", "self-test", "evidence", "verify-evidence"),
        default="validate",
    )
    parser.add_argument("--implementation-commit")
    parser.add_argument("--evidence-commit")
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    try:
        contract = load_json(
            HARDENED.capture_repository_file(CONTRACT_RELATIVE, "prepContract"),
            "prepContract",
        )
        if arguments.mode == "validate":
            output: object = validate_contract(contract)
        elif arguments.mode == "self-test":
            output = {
                "status": "PASS",
                "cases": adversarial_cases(contract),
                "invocationCounts": EXPECTED_SAFETY,
            }
        else:
            if not arguments.implementation_commit:
                reject("implementation_commit_required", arguments.mode)
            evidence = build_evidence(contract, arguments.implementation_commit)
            if arguments.mode == "evidence":
                output = evidence
            else:
                if not arguments.evidence_commit:
                    reject("evidence_commit_required", arguments.mode)
                output = {
                    "status": "PASS",
                    "evidence": validate_evidence(evidence, arguments.evidence_commit),
                }
        sys.stdout.buffer.write(canonical_bytes(output))
        return 0
    except (PrepRejected, HARDENED.ReplayRejected) as error:
        sys.stderr.buffer.write(
            canonical_bytes(
                {"status": "REJECTED", "code": error.code, "detail": error.detail}
            )
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
