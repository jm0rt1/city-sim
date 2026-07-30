#!/usr/bin/env python3
"""Replay immutable PLAY-079 East inputs without launching DCC or producing pixels."""

from __future__ import annotations

import argparse
import copy
import errno
import hashlib
import json
import os
import pathlib
import stat
import subprocess
import sys
import tempfile
from collections.abc import Callable
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
AUTHORED_BRANCH = "codex/citysim-world-art-east"
EXPECTED_BRANCHES = {AUTHORED_BRANCH, "master"}
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
CAPTURE_PROTECTIONS = {
    "parentDirectoryDescriptors": True,
    "oNoFollow": True,
    "beforeAfterFstat": True,
    "postReadLstat": True,
    "gitMode120000Rejected": True,
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


def require_object(value: object, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        reject("fixture_shape_invalid", f"{label}: expected object")
    return value


def require_list(value: object, label: str) -> list[Any]:
    if not isinstance(value, list):
        reject("fixture_shape_invalid", f"{label}: expected array")
    return value


def load_json_bytes(payload: bytes, label: str) -> dict[str, Any]:
    try:
        value = json.loads(payload)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ReplayRejected(f"{label}_invalid", error) from error
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


def _descriptor_flags(*, directory: bool) -> int:
    if not hasattr(os, "O_NOFOLLOW"):
        reject("o_nofollow_unavailable", sys.platform)
    flags = os.O_RDONLY | os.O_NOFOLLOW
    if directory:
        flags |= os.O_DIRECTORY
    if hasattr(os, "O_CLOEXEC"):
        flags |= os.O_CLOEXEC
    return flags


def _stat_identity(value: os.stat_result) -> tuple[int, ...]:
    return (
        value.st_dev,
        value.st_ino,
        value.st_mode,
        value.st_nlink,
        value.st_size,
        value.st_mtime_ns,
        value.st_ctime_ns,
    )


def _open_parent_descriptor(
    relative: str,
    label: str,
    *,
    repository_root: pathlib.Path,
) -> tuple[int, str]:
    parts = pathlib.PurePosixPath(relative).parts
    if len(parts) < 2:
        reject("input_parent_missing", f"{label}: {relative}")
    directory_fd: int | None = None
    try:
        directory_fd = os.open(repository_root, _descriptor_flags(directory=True))
        for component in parts[:-1]:
            next_fd = os.open(
                component,
                _descriptor_flags(directory=True),
                dir_fd=directory_fd,
            )
            os.close(directory_fd)
            directory_fd = next_fd
        return directory_fd, parts[-1]
    except FileNotFoundError as error:
        if directory_fd is not None:
            os.close(directory_fd)
        raise ReplayRejected("input_path_missing", f"{label}: {relative}") from error
    except OSError as error:
        if directory_fd is not None:
            os.close(directory_fd)
        code = (
            "input_symlink_component"
            if error.errno in {errno.ELOOP, errno.ENOTDIR}
            else "input_parent_open_failed"
        )
        raise ReplayRejected(code, f"{label}: {relative}: {error}") from error


def capture_repository_file(
    relative: str,
    label: str,
    *,
    repository_root: pathlib.Path | None = None,
    after_open_hook: Callable[[], None] | None = None,
    after_read_hook: Callable[[], None] | None = None,
    before_post_lstat_hook: Callable[[], None] | None = None,
) -> bytes:
    """Capture one regular file through no-follow parent and leaf descriptors."""

    safe_repo_relative(relative, label)
    root = REPOSITORY_ROOT if repository_root is None else repository_root
    parent_fd, leaf = _open_parent_descriptor(
        relative,
        label,
        repository_root=root,
    )
    file_fd: int | None = None
    try:
        file_fd = os.open(leaf, _descriptor_flags(directory=False), dir_fd=parent_fd)
        before = os.fstat(file_fd)
        if not stat.S_ISREG(before.st_mode):
            reject("input_leaf_not_regular", f"{label}: {relative}")
        if after_open_hook is not None:
            after_open_hook()
        chunks: list[bytes] = []
        while True:
            chunk = os.read(file_fd, 1024 * 1024)
            if not chunk:
                break
            chunks.append(chunk)
        if after_read_hook is not None:
            after_read_hook()
        after = os.fstat(file_fd)
        if _stat_identity(before) != _stat_identity(after):
            reject("input_changed_during_read", f"{label}: {relative}")
        if before_post_lstat_hook is not None:
            before_post_lstat_hook()
        terminal = os.lstat(leaf, dir_fd=parent_fd)
        if not stat.S_ISREG(terminal.st_mode):
            reject("input_terminal_not_regular", f"{label}: {relative}")
        if _stat_identity(after) != _stat_identity(terminal):
            reject("input_terminal_replaced", f"{label}: {relative}")
        return b"".join(chunks)
    except FileNotFoundError as error:
        raise ReplayRejected("input_path_missing", f"{label}: {relative}") from error
    except OSError as error:
        code = (
            "input_symlink_component"
            if error.errno == errno.ELOOP
            else "input_read_failed"
        )
        raise ReplayRejected(code, f"{label}: {relative}: {error}") from error
    finally:
        if file_fd is not None:
            os.close(file_fd)
        os.close(parent_fd)


def git_run(
    *arguments: str,
    text: bool = True,
    repository_root: pathlib.Path | None = None,
) -> subprocess.CompletedProcess[Any]:
    return subprocess.run(
        ["git", *arguments],
        cwd=REPOSITORY_ROOT if repository_root is None else repository_root,
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


def git_tree_entry(
    commit: str,
    relative: str,
    label: str,
    *,
    repository_root: pathlib.Path | None = None,
) -> dict[str, str]:
    safe_repo_relative(relative, f"{label}.gitPath")
    completed = git_run(
        "ls-tree",
        "-z",
        commit,
        "--",
        relative,
        text=False,
        repository_root=repository_root,
    )
    if completed.returncode != 0:
        reject("git_tree_unreadable", f"{label}: {commit}:{relative}")
    records = [record for record in completed.stdout.split(b"\0") if record]
    if len(records) != 1:
        reject("git_blob_missing", f"{label}: {commit}:{relative}")
    try:
        metadata, encoded_path = records[0].split(b"\t", 1)
        mode, kind, object_id = metadata.split(b" ", 2)
        observed_path = encoded_path.decode("utf-8")
    except (ValueError, UnicodeDecodeError) as error:
        raise ReplayRejected("git_tree_entry_invalid", label) from error
    if observed_path != relative:
        reject("git_tree_path_mismatch", f"{observed_path} != {relative}")
    mode_text = mode.decode("ascii")
    kind_text = kind.decode("ascii")
    object_text = object_id.decode("ascii")
    if mode_text == "120000":
        reject("git_symlink_mode_rejected", f"{label}: {commit}:{relative}")
    if mode_text not in {"100644", "100755"}:
        reject("git_mode_not_regular", f"{label}: {mode_text}")
    if kind_text != "blob":
        reject("git_object_not_blob", f"{label}: {kind_text}")
    return {"mode": mode_text, "type": kind_text, "objectId": object_text}


def git_blob(
    commit: str,
    relative: str,
    label: str,
    *,
    repository_root: pathlib.Path | None = None,
) -> tuple[bytes, dict[str, str]]:
    entry = git_tree_entry(
        commit,
        relative,
        label,
        repository_root=repository_root,
    )
    completed = git_run(
        "cat-file",
        "blob",
        entry["objectId"],
        text=False,
        repository_root=repository_root,
    )
    if completed.returncode != 0:
        reject("git_blob_unreadable", f"{label}: {entry['objectId']}")
    return completed.stdout, entry


def validate_binding(
    value: object,
    expected: dict[str, str],
    base_commit: str,
    label: str,
) -> tuple[dict[str, Any], bytes]:
    binding = require_object(value, label)
    path = safe_repo_relative(binding.get("path"), f"{label}.path")
    if path != expected["path"]:
        reject(f"{label}_path_mismatch", f"{path} != {expected['path']}")
    digest = binding.get("sha256")
    if digest != expected["sha256"]:
        reject(f"{label}_hash_mismatch", f"{digest} != {expected['sha256']}")
    blob_payload, tree_entry = git_blob(base_commit, path, label)
    blob_digest = sha256_bytes(blob_payload)
    if blob_digest != digest:
        reject(f"{label}_git_blob_hash_mismatch", f"{blob_digest} != {digest}")
    working_payload = capture_repository_file(path, label)
    working_digest = sha256_bytes(working_payload)
    if working_digest != digest:
        reject(f"{label}_working_tree_hash_mismatch", f"{working_digest} != {digest}")
    return (
        {
            "path": path,
            "sha256": digest,
            "gitObjectType": tree_entry["type"],
            "gitMode": tree_entry["mode"],
            "gitObjectId": tree_entry["objectId"],
            "captureProtections": CAPTURE_PROTECTIONS,
        },
        working_payload,
    )


def branch_identity(replay_branch: str) -> dict[str, str]:
    if replay_branch not in EXPECTED_BRANCHES:
        reject("branch_mismatch", replay_branch)
    return {
        "authoredBranch": AUTHORED_BRANCH,
        "replayBranch": replay_branch,
    }


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
        **branch_identity(branch),
        "authorizedBranches": sorted(EXPECTED_BRANCHES),
        "ancestry": "PASS",
    }


def validate_socket(
    value: object,
    scene_payload: bytes,
    runner_payload: bytes,
) -> dict[str, list[float]]:
    socket = require_object(value, "eastSocket")
    if socket != EXPECTED_SOCKET:
        reject("east_socket_mismatch", socket)
    scene = load_json_bytes(scene_payload, "scene")
    runner = load_json_bytes(runner_payload, "runner_contract")
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
    authority, _authority_payload = validate_binding(
        value.get("authority"),
        EXPECTED_AUTHORITY,
        EXPECTED_BASE_AUTHORITY,
        "authority",
    )
    inputs_value = require_object(value.get("immutableInputs"), "immutableInputs")
    inputs: dict[str, dict[str, Any]] = {}
    input_payloads: dict[str, bytes] = {}
    for name, expected in EXPECTED_INPUTS.items():
        validated, payload = validate_binding(
            inputs_value.get(name),
            expected,
            EXPECTED_BASE_AUTHORITY,
            name,
        )
        inputs[name] = validated
        input_payloads[name] = payload
    socket = validate_socket(
        value.get("eastSocket"),
        input_payloads["scene"],
        input_payloads["runnerContract"],
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


def _expect_rejection(
    case_id: str,
    expected_code: str,
    operation: Callable[[], object],
) -> dict[str, str]:
    try:
        operation()
    except ReplayRejected as error:
        if error.code != expected_code:
            reject(
                "capture_adversarial_code_mismatch",
                f"{case_id}: {error.code} != {expected_code}",
            )
        return {"id": case_id, "result": "REJECTED", "code": error.code}
    reject("capture_adversarial_case_accepted", case_id)


def _fixture_git(root: pathlib.Path, *arguments: str) -> str:
    completed = subprocess.run(
        ["git", *arguments],
        cwd=root,
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        reject(
            "capture_adversarial_git_failed",
            f"git {' '.join(arguments)}: {completed.stderr.strip()}",
        )
    return completed.stdout.strip()


def validate_capture_adversaries(value: dict[str, Any]) -> list[dict[str, str]]:
    specification = require_list(
        value.get("captureAdversaries"),
        "captureAdversaries",
    )
    expected = {
        str(require_object(case, "captureAdversaries[]").get("id")): str(
            require_object(case, "captureAdversaries[]").get("expectedCode")
        )
        for case in specification
    }
    required = {
        "symlinked_git_blob": "git_symlink_mode_rejected",
        "terminal_replacement": "input_terminal_replaced",
        "in_place_mutation": "input_changed_during_read",
    }
    if expected != required:
        reject("capture_adversarial_specification_mismatch", expected)

    results: list[dict[str, str]] = []
    with tempfile.TemporaryDirectory(prefix="play079-capture-adversaries-") as temporary:
        root = pathlib.Path(temporary)

        git_root = root / "git-symlink"
        git_root.mkdir()
        _fixture_git(git_root, "init", "-q")
        _fixture_git(git_root, "config", "user.name", "PLAY-079 Fixture")
        _fixture_git(
            git_root,
            "config",
            "user.email",
            "play079@example.invalid",
        )
        (git_root / "target.txt").write_bytes(b"target\n")
        (git_root / "authority.txt").symlink_to("target.txt")
        _fixture_git(git_root, "add", "authority.txt")
        _fixture_git(git_root, "commit", "-q", "-m", "symlink fixture")
        fixture_commit = _fixture_git(git_root, "rev-parse", "HEAD")
        results.append(
            _expect_rejection(
                "symlinked_git_blob",
                required["symlinked_git_blob"],
                lambda: git_blob(
                    fixture_commit,
                    "authority.txt",
                    "symlink_fixture",
                    repository_root=git_root,
                ),
            )
        )

        replacement_root = root / "terminal-replacement"
        (replacement_root / "inputs").mkdir(parents=True)
        replacement_path = replacement_root / "inputs/authority.json"
        replacement_path.write_bytes(b'{"authority":"original"}\n')

        def replace_terminal() -> None:
            replacement_path.unlink()
            replacement_path.write_bytes(b'{"authority":"replacement"}\n')

        results.append(
            _expect_rejection(
                "terminal_replacement",
                required["terminal_replacement"],
                lambda: capture_repository_file(
                    "inputs/authority.json",
                    "terminal_replacement_fixture",
                    repository_root=replacement_root,
                    before_post_lstat_hook=replace_terminal,
                ),
            )
        )

        mutation_root = root / "in-place-mutation"
        (mutation_root / "inputs").mkdir(parents=True)
        mutation_path = mutation_root / "inputs/authority.json"
        mutation_path.write_bytes(b'{"authority":"original"}\n')

        def mutate_in_place() -> None:
            with mutation_path.open("r+b") as stream:
                stream.seek(0)
                stream.write(b'{"authority":"mutated!"}\n')
                stream.flush()
                os.fsync(stream.fileno())

        results.append(
            _expect_rejection(
                "in_place_mutation",
                required["in_place_mutation"],
                lambda: capture_repository_file(
                    "inputs/authority.json",
                    "in_place_mutation_fixture",
                    repository_root=mutation_root,
                    after_read_hook=mutate_in_place,
                ),
            )
        )
    return results


def validate_committed_implementation(commit: str) -> dict[str, str]:
    if len(commit) != 40 or any(character not in "0123456789abcdef" for character in commit):
        reject("implementation_commit_invalid", commit)
    ancestry = git_run("merge-base", "--is-ancestor", commit, "HEAD")
    if ancestry.returncode != 0:
        reject("implementation_commit_not_ancestor", commit)
    relative = SCRIPT_PATH.relative_to(REPOSITORY_ROOT).as_posix()
    blob_payload, tree_entry = git_blob(commit, relative, "implementation")
    blob_digest = sha256_bytes(blob_payload)
    working_digest = sha256_bytes(
        capture_repository_file(relative, "implementation")
    )
    if blob_digest != working_digest:
        reject(
            "implementation_working_tree_hash_mismatch",
            f"{blob_digest} != {working_digest}",
        )
    return {
        "commit": commit,
        "path": relative,
        "sha256": blob_digest,
        "gitMode": tree_entry["mode"],
        "gitObjectId": tree_entry["objectId"],
    }


def build_receipt(value: dict[str, Any], implementation_commit: str) -> dict[str, Any]:
    first = validate_fixture(value)
    second = validate_fixture(value)
    first_bytes = canonical_bytes(first)
    second_bytes = canonical_bytes(second)
    if first_bytes != second_bytes:
        reject("deterministic_validation_mismatch", "run 1 != run 2")
    fixture_negatives = validate_adversarial_cases(value)
    capture_negatives = validate_capture_adversaries(value)
    implementation = validate_committed_implementation(implementation_commit)
    fixture_relative = FIXTURE_PATH.relative_to(REPOSITORY_ROOT).as_posix()
    fixture_payload = capture_repository_file(fixture_relative, "fixture")
    if load_json_bytes(fixture_payload, "fixture") != value:
        reject("fixture_changed_before_receipt", fixture_relative)
    return {
        "schema": "citysim.play-079.current-master-immutable-input-replay.v2",
        "schemaVersion": 2,
        "taskId": EXPECTED_TASK,
        "direction": EXPECTED_DIRECTION,
        "authoredBranch": first["baseAuthority"]["authoredBranch"],
        "replayBranch": first["baseAuthority"]["replayBranch"],
        "baseAuthority": EXPECTED_BASE_AUTHORITY,
        "result": "PASS",
        "implementation": implementation,
        "fixture": {
            "path": fixture_relative,
            "sha256": sha256_bytes(fixture_payload),
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
        "captureProtections": CAPTURE_PROTECTIONS,
        "adversarialCases": {
            "fixture": fixture_negatives,
            "capture": capture_negatives,
        },
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
    return candidate


def main() -> int:
    args = parse_arguments()
    try:
        exact_fixture_path(args.fixture)
        fixture_relative = FIXTURE_PATH.relative_to(REPOSITORY_ROOT).as_posix()
        fixture = load_json_bytes(
            capture_repository_file(fixture_relative, "fixture"),
            "fixture",
        )
        if args.command == "validate":
            output: object = validate_fixture(fixture)
        elif args.command == "adversarial":
            output = {
                "result": "PASS",
                "fixtureCases": validate_adversarial_cases(fixture),
                "captureCases": validate_capture_adversaries(fixture),
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
