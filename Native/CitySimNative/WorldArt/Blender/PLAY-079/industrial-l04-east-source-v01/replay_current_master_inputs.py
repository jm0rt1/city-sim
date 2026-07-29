#!/usr/bin/env python3
"""Replay immutable PLAY-079 East inputs without launching DCC or producing pixels."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import pathlib
import stat
import subprocess
import sys
from typing import Any, NoReturn


SOURCE_ROOT = pathlib.Path(__file__).resolve().parent
REPOSITORY_ROOT = SOURCE_ROOT.parents[5]
FIXTURE_PATH = SOURCE_ROOT / "fixtures/current-master-replay/REPLAY-FIXTURE.json"
SCRIPT_PATH = SOURCE_ROOT / "replay_current_master_inputs.py"
EVIDENCE_PATH = (
    REPOSITORY_ROOT
    / "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/"
    "CURRENT-MASTER-IMMUTABLE-INPUT-REPLAY.json"
)

EXPECTED_BASE_AUTHORITY = "94ae73a99abe64f59bb052582fcaba1d9725319d"
EXPECTED_BRANCH = "codex/citysim-world-art-east"
EXPECTED_BRANCHES = {EXPECTED_BRANCH, "master"}
EXPECTED_TASK = "PLAY-079"
EXPECTED_DIRECTION = "east"
EXPECTED_SOURCE_ROOT = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
    "industrial-l04-east-source-v01/"
)
EXPECTED_EVIDENCE_ROOT = (
    "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/"
)
EXPECTED_RECEIPT_PATH = (
    f"{EXPECTED_EVIDENCE_ROOT}CURRENT-MASTER-IMMUTABLE-INPUT-REPLAY.json"
)
EXPECTED_AUTHORITY = {
    "path": (
        "docs/production/evidence/INTEGRATION/"
        "INDUSTRIAL-L04-PARALLEL-EXECUTION-CONTRACT-CANDIDATE.md"
    ),
    "sha256": "a2c726585fa83f9a795c02cb4e97fd476ae3969587db7c5e133ecc9889636e36",
}
EXPECTED_INPUTS = {
    "claim": {
        "path": "docs/production/claims/PLAY-079.world-art-east.md",
        "sha256": "5439d720e0a4c90e7310a7fd94ad1a94dd18497df4ef048de726e33405670fab",
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
    "runnerContract": {
        "path": f"{EXPECTED_SOURCE_ROOT}RUNNER-CONTRACT.json",
        "sha256": "5302750257a0bc158f6b460f78a48dccd22c2194f169deb8e46e5c61f1204da8",
    },
}
EXPECTED_SOCKET = {
    "citySim": [28.0, 0.0, 0.0],
    "blenderNative": [0.0, 28.0, 0.0],
    "sourcePixel": [896.0, 832.0],
}
PIXEL_SUFFIXES = {
    ".bmp",
    ".exr",
    ".jpeg",
    ".jpg",
    ".png",
    ".tif",
    ".tiff",
    ".webp",
}


class ReplayRejected(RuntimeError):
    """Stable fail-closed replay rejection."""

    def __init__(self, code: str, detail: object):
        super().__init__(str(detail))
        self.code = code
        self.detail = str(detail)


def reject(code: str, detail: object) -> NoReturn:
    raise ReplayRejected(code, detail)


def canonical_bytes(value: object) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
        + "\n"
    ).encode("utf-8")


def sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def sha256_file(path: pathlib.Path) -> str:
    try:
        return sha256_bytes(path.read_bytes())
    except OSError as error:
        raise ReplayRejected("input_unreadable", f"{path}: {error}") from error


def require_object(value: object, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        reject("fixture_shape_invalid", f"{label}: expected object")
    return value


def require_list(value: object, label: str) -> list[Any]:
    if not isinstance(value, list):
        reject("fixture_shape_invalid", f"{label}: expected array")
    return value


def load_json_file(path: pathlib.Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ReplayRejected(f"{label}_invalid", f"{path}: {error}") from error
    return require_object(value, label)


def safe_repo_relative(value: object, label: str) -> str:
    if not isinstance(value, str) or not value or value.startswith("/") or "\\" in value:
        reject("unsafe_repository_path", f"{label}: {value!r}")
    normalized = value[:-1] if value.endswith("/") else value
    pure = pathlib.PurePosixPath(normalized)
    if (
        not normalized
        or pure.as_posix() != normalized
        or "//" in value
        or any(part in {"", ".", ".."} for part in pure.parts)
    ):
        reject("unsafe_repository_path", f"{label}: {value!r}")
    return value


def reject_symlink_components(relative: str, label: str) -> None:
    current = REPOSITORY_ROOT
    for component in pathlib.PurePosixPath(relative).parts:
        current = current / component
        try:
            status = os.lstat(current)
        except FileNotFoundError:
            reject("input_path_missing", f"{label}: {relative}")
        except OSError as error:
            raise ReplayRejected("input_path_unreadable", f"{relative}: {error}") from error
        if stat.S_ISLNK(status.st_mode):
            reject("input_symlink_component", f"{label}: {relative}")


def git_run(*arguments: str, text: bool = True) -> subprocess.CompletedProcess[Any]:
    return subprocess.run(
        ["git", *arguments],
        cwd=REPOSITORY_ROOT,
        check=False,
        capture_output=True,
        text=text,
    )


def git_text(*arguments: str) -> str:
    completed = git_run(*arguments)
    if completed.returncode != 0:
        reject(
            "git_identity_unavailable",
            f"git {' '.join(arguments)}: {completed.stderr.strip()}",
        )
    return completed.stdout.strip()


def git_blob(commit: str, relative: str, label: str) -> bytes:
    object_name = f"{commit}:{relative}"
    kind = git_run("cat-file", "-t", object_name)
    if kind.returncode != 0:
        reject("git_blob_missing", f"{label}: {object_name}")
    if kind.stdout.strip() != "blob":
        reject("git_object_not_blob", f"{label}: {object_name}")
    completed = git_run("show", object_name, text=False)
    if completed.returncode != 0:
        reject("git_blob_unreadable", f"{label}: {object_name}")
    return completed.stdout


def validate_binding(
    value: object,
    expected: dict[str, str],
    base_commit: str,
    label: str,
) -> dict[str, str]:
    binding = require_object(value, label)
    path = safe_repo_relative(binding.get("path"), f"{label}.path")
    if path != expected["path"]:
        reject(f"{label}_path_mismatch", f"{path} != {expected['path']}")
    digest = binding.get("sha256")
    if digest != expected["sha256"]:
        reject(f"{label}_hash_mismatch", f"{digest} != {expected['sha256']}")
    reject_symlink_components(path, label)
    blob_digest = sha256_bytes(git_blob(base_commit, path, label))
    if blob_digest != digest:
        reject(f"{label}_git_blob_hash_mismatch", f"{blob_digest} != {digest}")
    working_digest = sha256_file(REPOSITORY_ROOT / pathlib.PurePosixPath(path))
    if working_digest != digest:
        reject(f"{label}_working_tree_hash_mismatch", f"{working_digest} != {digest}")
    return {"path": path, "sha256": digest, "gitObjectType": "blob"}


def validate_branch_and_ancestry(base_commit: str) -> dict[str, object]:
    if base_commit != EXPECTED_BASE_AUTHORITY:
        reject(
            "base_authority_mismatch",
            f"{base_commit} != {EXPECTED_BASE_AUTHORITY}",
        )
    branch = git_text("branch", "--show-current")
    if branch not in EXPECTED_BRANCHES:
        reject("branch_mismatch", branch)
    ancestry = git_run("merge-base", "--is-ancestor", base_commit, "HEAD")
    if ancestry.returncode != 0:
        reject("base_authority_not_ancestor", base_commit)
    return {
        "baseCommit": base_commit,
        "authorizedBranches": sorted(EXPECTED_BRANCHES),
        "ancestry": "PASS",
    }


def validate_socket(
    value: object,
    scene_binding: dict[str, str],
    runner_binding: dict[str, str],
) -> dict[str, list[float]]:
    socket = require_object(value, "eastSocket")
    if socket != EXPECTED_SOCKET:
        reject("east_socket_mismatch", socket)
    scene = load_json_file(
        REPOSITORY_ROOT / pathlib.PurePosixPath(scene_binding["path"]),
        "scene",
    )
    runner = load_json_file(
        REPOSITORY_ROOT / pathlib.PurePosixPath(runner_binding["path"]),
        "runner_contract",
    )
    registration = require_object(scene.get("registration"), "scene.registration")
    expected_pixels = require_object(
        registration.get("expectedSourcePixels"),
        "scene.registration.expectedSourcePixels",
    )
    if registration.get("frontage") != EXPECTED_DIRECTION:
        reject("scene_direction_mismatch", registration.get("frontage"))
    observed = {
        "citySim": registration.get("frontageSocket"),
        "sourcePixel": expected_pixels.get("frontageSocket"),
        "blenderNative": (
            require_object(
                require_object(runner.get("invariants"), "runner.invariants").get(
                    "coordinateBridge"
                ),
                "runner.invariants.coordinateBridge",
            ).get("blenderNativeEastSocket")
        ),
    }
    if observed != EXPECTED_SOCKET:
        reject("east_socket_source_mismatch", observed)
    return EXPECTED_SOCKET


def validate_roots(value: object) -> dict[str, str]:
    roots = require_object(value, "roots")
    source_root = safe_repo_relative(roots.get("source"), "roots.source")
    evidence_root = safe_repo_relative(roots.get("evidence"), "roots.evidence")
    receipt = safe_repo_relative(roots.get("receipt"), "roots.receipt")
    if source_root != EXPECTED_SOURCE_ROOT:
        reject("source_root_mismatch", source_root)
    if evidence_root != EXPECTED_EVIDENCE_ROOT:
        reject("output_root_mismatch", evidence_root)
    if receipt != EXPECTED_RECEIPT_PATH:
        reject("receipt_path_mismatch", receipt)
    if not receipt.startswith(evidence_root):
        reject("receipt_outside_east_root", receipt)
    return {"source": source_root, "evidence": evidence_root, "receipt": receipt}


def pixel_inventory() -> list[str]:
    evidence_root = REPOSITORY_ROOT / pathlib.PurePosixPath(EXPECTED_EVIDENCE_ROOT)
    return sorted(
        path.relative_to(REPOSITORY_ROOT).as_posix()
        for path in evidence_root.rglob("*")
        if path.is_file() and path.suffix.lower() in PIXEL_SUFFIXES
    )


def validate_fixture(value: dict[str, Any]) -> dict[str, Any]:
    if value.get("schema") != "citysim.play-079.current-master-replay-fixture.v1":
        reject("fixture_schema_mismatch", value.get("schema"))
    if value.get("taskId") != EXPECTED_TASK:
        reject("task_mismatch", value.get("taskId"))
    if value.get("direction") != EXPECTED_DIRECTION:
        reject("direction_mismatch", value.get("direction"))

    base = validate_branch_and_ancestry(str(value.get("baseAuthority")))
    authority = validate_binding(
        value.get("authority"),
        EXPECTED_AUTHORITY,
        EXPECTED_BASE_AUTHORITY,
        "authority",
    )
    inputs_value = require_object(value.get("immutableInputs"), "immutableInputs")
    inputs = {
        name: validate_binding(
            inputs_value.get(name),
            expected,
            EXPECTED_BASE_AUTHORITY,
            name,
        )
        for name, expected in EXPECTED_INPUTS.items()
    }
    socket = validate_socket(
        value.get("eastSocket"),
        inputs["scene"],
        inputs["runnerContract"],
    )
    roots = validate_roots(value.get("roots"))
    pixels = pixel_inventory()
    if pixels:
        reject("pixel_files_present", pixels)
    return {
        "result": "PASS",
        "baseAuthority": base,
        "authority": authority,
        "immutableInputs": inputs,
        "eastSocket": socket,
        "roots": roots,
        "pixelFiles": pixels,
    }


def set_pointer(value: Any, pointer: str, replacement: Any) -> None:
    if not pointer.startswith("/"):
        reject("adversarial_pointer_invalid", pointer)
    current = value
    parts = pointer[1:].split("/")
    for part in parts[:-1]:
        current = current[int(part)] if isinstance(current, list) else current[part]
    leaf = parts[-1]
    if isinstance(current, list):
        current[int(leaf)] = replacement
    else:
        current[leaf] = replacement


def validate_adversarial_cases(value: dict[str, Any]) -> list[dict[str, str]]:
    cases = require_list(value.get("adversarialCases"), "adversarialCases")
    results: list[dict[str, str]] = []
    for raw_case in cases:
        case = require_object(raw_case, "adversarialCases[]")
        mutated = copy.deepcopy(value)
        mutated.pop("adversarialCases", None)
        set_pointer(mutated, str(case.get("pointer")), case.get("value"))
        expected = case.get("expectedCode")
        try:
            validate_fixture(mutated)
        except ReplayRejected as error:
            if error.code != expected:
                reject(
                    "adversarial_code_mismatch",
                    f"{case.get('id')}: {error.code} != {expected}",
                )
            results.append(
                {
                    "id": str(case.get("id")),
                    "result": "REJECTED",
                    "code": error.code,
                }
            )
        else:
            reject("adversarial_case_accepted", case.get("id"))
    return results


def validate_committed_implementation(commit: str) -> dict[str, str]:
    if len(commit) != 40 or any(character not in "0123456789abcdef" for character in commit):
        reject("implementation_commit_invalid", commit)
    ancestry = git_run("merge-base", "--is-ancestor", commit, "HEAD")
    if ancestry.returncode != 0:
        reject("implementation_commit_not_ancestor", commit)
    relative = SCRIPT_PATH.relative_to(REPOSITORY_ROOT).as_posix()
    blob_digest = sha256_bytes(git_blob(commit, relative, "implementation"))
    working_digest = sha256_file(SCRIPT_PATH)
    if blob_digest != working_digest:
        reject(
            "implementation_working_tree_hash_mismatch",
            f"{blob_digest} != {working_digest}",
        )
    return {"commit": commit, "path": relative, "sha256": blob_digest}


def build_receipt(value: dict[str, Any], implementation_commit: str) -> dict[str, Any]:
    first = validate_fixture(value)
    second = validate_fixture(value)
    first_bytes = canonical_bytes(first)
    second_bytes = canonical_bytes(second)
    if first_bytes != second_bytes:
        reject("deterministic_validation_mismatch", "run 1 != run 2")
    negatives = validate_adversarial_cases(value)
    implementation = validate_committed_implementation(implementation_commit)
    return {
        "schema": "citysim.play-079.current-master-immutable-input-replay.v1",
        "schemaVersion": 1,
        "taskId": EXPECTED_TASK,
        "direction": EXPECTED_DIRECTION,
        "branch": EXPECTED_BRANCH,
        "baseAuthority": EXPECTED_BASE_AUTHORITY,
        "result": "PASS",
        "implementation": implementation,
        "fixture": {
            "path": FIXTURE_PATH.relative_to(REPOSITORY_ROOT).as_posix(),
            "sha256": sha256_file(FIXTURE_PATH),
        },
        "deterministicValidations": {
            "runs": 2,
            "byteIdentical": True,
            "resultSha256": sha256_bytes(first_bytes),
        },
        "immutableInputs": first["immutableInputs"],
        "authority": first["authority"],
        "eastSocket": first["eastSocket"],
        "roots": first["roots"],
        "adversarialCases": negatives,
        "predesignBytesPreserved": {
            "sceneSha256": first["immutableInputs"]["scene"]["sha256"],
            "materialsSha256": first["immutableInputs"]["materials"]["sha256"],
        },
        "invocations": {
            "blenderProcesses": 0,
            "blenderRenderApiCalls": 0,
            "dccProcesses": 0,
            "imageGenInvocations": 0,
            "normalizerInvocations": 0,
            "contactSheetInvocations": 0,
            "sourceProcessInvocations": 0,
        },
        "outputs": {
            "pixelFilesCreated": 0,
            "processABCProduced": False,
            "sourcePacketsProduced": 0,
            "productionReceiptsProduced": 0,
            "deterministicReplayReceipt": EXPECTED_RECEIPT_PATH,
        },
        "sourceReady": False,
        "integrationAdmitted": False,
        "productionSelected": False,
    }


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Zero-DCC immutable-input replay for PLAY-079 East."
    )
    parser.add_argument("command", choices=("validate", "adversarial", "receipt"))
    parser.add_argument("--fixture", required=True)
    parser.add_argument("--implementation-commit")
    return parser.parse_args()


def exact_fixture_path(value: str) -> pathlib.Path:
    candidate = pathlib.Path(value)
    if not candidate.is_absolute():
        candidate = REPOSITORY_ROOT / candidate
    if candidate != FIXTURE_PATH:
        reject("fixture_path_mismatch", candidate)
    reject_symlink_components(
        FIXTURE_PATH.relative_to(REPOSITORY_ROOT).as_posix(),
        "fixture",
    )
    return candidate


def main() -> int:
    args = parse_arguments()
    try:
        fixture = load_json_file(exact_fixture_path(args.fixture), "fixture")
        if args.command == "validate":
            output: object = validate_fixture(fixture)
        elif args.command == "adversarial":
            output = {
                "result": "PASS",
                "cases": validate_adversarial_cases(fixture),
            }
        else:
            if not args.implementation_commit:
                reject("implementation_commit_missing", "--implementation-commit")
            output = build_receipt(fixture, args.implementation_commit)
    except ReplayRejected as error:
        sys.stdout.buffer.write(
            canonical_bytes(
                {
                    "result": "REJECTED",
                    "code": error.code,
                    "detail": error.detail,
                    "invocations": {
                        "blenderProcesses": 0,
                        "dccProcesses": 0,
                        "imageGenInvocations": 0,
                        "normalizerInvocations": 0,
                    },
                    "pixelFilesCreated": 0,
                }
            )
        )
        return 2
    sys.stdout.buffer.write(canonical_bytes(output))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
