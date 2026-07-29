#!/usr/bin/env python3
"""Fail-closed PLAY-080 source-candidate packet writer boundary.

The normal path validates an external candidate packet before creating the
Integration-reserved South packet with exclusive, nofollow semantics.  Dry-run
mode performs the same gates but never opens the destination for writing.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import subprocess
import sys
from pathlib import Path, PurePosixPath
from typing import Any, Callable

try:
    from jsonschema import Draft202012Validator
except ImportError as error:  # pragma: no cover - deliberately fail closed
    raise SystemExit(f"MISSING_JSONSCHEMA: {error}") from error


SOURCE_DIR = Path(__file__).resolve().parent
REPOSITORY_ROOT = SOURCE_DIR.parents[5]

TASK_ID = "PLAY-080"
DIRECTION = "south"
BRANCH = "codex/citysim-world-art-south"
SOURCE_ROOT = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-080/"
    "industrial-l04-south-source-v01"
)
EVIDENCE_ROOT = (
    "docs/production/evidence/PLAY-080/industrial-l04-south-source-v01"
)
RESERVED_PACKET_PATH = f"{EVIDENCE_ROOT}/SOURCE-STAGE-HANDOFF-V2.json"
STRICT_RECEIPT_PATH = (
    f"{EVIDENCE_ROOT}/FUTURE-SOURCE-PARALLEL-EXECUTION-RECEIPT.json"
)

LOCATOR_AUTHORITY_COMMIT = "fa66b5605deca987685c058a072613e89a0d8be9"
LOCATOR_SCHEMA_PATH = (
    "docs/production/evidence/INTEGRATION/"
    "industrial-l04-source-candidate-packet-locators-v1.schema.json"
)
LOCATOR_SCHEMA_SHA256 = (
    "cb9716330593224bc5cbdae46052cff17cbb84a270ca9976c5452b8075308cbe"
)
LOCATOR_INSTANCE_PATH = (
    "docs/production/evidence/INTEGRATION/"
    "industrial-l04-source-candidate-packet-locators-v1.json"
)
LOCATOR_INSTANCE_SHA256 = (
    "a2c8daf558274bed9088b6c9ab616044e919af5b19101a01c2fe3a1b89122e65"
)
SOURCE_STAGE_SCHEMA_PATH = (
    "docs/production/evidence/INTEGRATION/"
    "industrial-l04-source-stage-handoff-schema-v2.json"
)
SOURCE_STAGE_SCHEMA_SHA256 = (
    "93efe9ca6d000a2d145098f722338c8e85829d6de6724c3f231a93c06eadf3d7"
)
SOURCE_STAGE_VALIDATOR_PATH = (
    "Native/CitySimNative/WorldArt/Shared/"
    "validate_source_stage_handoff_v2.py"
)
SOURCE_STAGE_VALIDATOR_SHA256 = (
    "7a0613af9998a222a583a70930ce3afc5ec1902793f03201f899a2bb4129f340"
)
STRICT_SCHEMA_PATH = (
    f"{SOURCE_ROOT}/strict-parallel-receipt-prototype-v01/"
    "strict-parallel-execution-receipt-fixture-schema-v1.json"
)
STRICT_VALIDATOR_PATH = (
    f"{SOURCE_ROOT}/strict-parallel-receipt-prototype-v01/"
    "validate_strict_parallel_receipt_fixture.py"
)
HEX_40 = re.compile(r"^[0-9a-f]{40}$")

ValidationRunner = Callable[[Path, dict[str, Any]], dict[str, Any]]


class PacketWriterRejected(RuntimeError):
    """Stable fail-closed rejection."""

    def __init__(self, code: str, detail: Any):
        super().__init__(code)
        self.code = code
        self.detail = detail


def reject(code: str, detail: Any) -> None:
    raise PacketWriterRejected(code, detail)


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    try:
        return sha256_bytes(path.read_bytes())
    except OSError as error:
        reject("AUTHORITY_FILE_UNREADABLE", {"path": str(path), "error": str(error)})


def strict_json_bytes(value: bytes, label: str) -> Any:
    def reject_constant(constant: str) -> None:
        reject("NONFINITE_JSON_NUMBER", {"label": label, "value": constant})

    def unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, child in pairs:
            if key in result:
                reject("DUPLICATE_JSON_KEY", {"label": label, "key": key})
            result[key] = child
        return result

    try:
        return json.loads(
            value.decode("utf-8"),
            parse_constant=reject_constant,
            object_pairs_hook=unique_object,
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        reject("INVALID_JSON", {"label": label, "error": str(error)})


def canonical_json_bytes(value: dict[str, Any]) -> bytes:
    return (
        json.dumps(value, indent=2, sort_keys=True, ensure_ascii=True) + "\n"
    ).encode("ascii")


def git(repo: Path, *arguments: str, allow_failure: bool = False) -> str:
    result = subprocess.run(
        ["git", "-C", str(repo), *arguments],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode and not allow_failure:
        reject(
            "GIT_COMMAND_FAILED",
            {
                "arguments": list(arguments),
                "returnCode": result.returncode,
                "stderr": result.stderr.strip(),
            },
        )
    return result.stdout.strip()


def require_commit(repo: Path, commit: Any, label: str) -> str:
    if not isinstance(commit, str) or HEX_40.fullmatch(commit) is None:
        reject("INVALID_CONTENT_COMMIT", {"label": label, "value": commit})
    result = subprocess.run(
        ["git", "-C", str(repo), "cat-file", "-e", f"{commit}^{{commit}}"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if result.returncode:
        reject("MISSING_CONTENT_COMMIT", {"label": label, "value": commit})
    return commit


def require_ancestor(repo: Path, ancestor: str, descendant: str, label: str) -> None:
    result = subprocess.run(
        ["git", "-C", str(repo), "merge-base", "--is-ancestor", ancestor, descendant],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if result.returncode:
        reject(
            "CONTENT_COMMIT_ANCESTRY_MISMATCH",
            {"label": label, "ancestor": ancestor, "descendant": descendant},
        )


def require_file_at_commit(
    repo: Path,
    commit: str,
    relative_path: str,
    expected_sha256: str,
) -> None:
    result = subprocess.run(
        ["git", "-C", str(repo), "show", f"{commit}:{relative_path}"],
        check=False,
        capture_output=True,
    )
    if result.returncode:
        reject(
            "AUTHORITY_FILE_NOT_IN_COMMIT",
            {"commit": commit, "path": relative_path},
        )
    actual = sha256_bytes(result.stdout)
    if actual != expected_sha256:
        reject(
            "AUTHORITY_COMMIT_CONTENT_DRIFT",
            {
                "commit": commit,
                "path": relative_path,
                "expected": expected_sha256,
                "actual": actual,
            },
        )


def safe_relative_path(value: Any, label: str) -> PurePosixPath:
    if (
        not isinstance(value, str)
        or not value
        or "\\" in value
        or value.startswith("/")
        or "//" in value
    ):
        reject("UNSAFE_ROOT", {"label": label, "path": value})
    raw_parts = value.split("/")
    if any(part in {"", ".", ".."} for part in raw_parts):
        reject("UNSAFE_ROOT", {"label": label, "path": value})
    pure = PurePosixPath(value)
    if pure.is_absolute():
        reject("UNSAFE_ROOT", {"label": label, "path": value})
    return pure


def load_locator_authority(
    repo: Path,
    *,
    schema_path: Path | None = None,
    instance_path: Path | None = None,
) -> dict[str, Any]:
    schema_file = schema_path or repo / LOCATOR_SCHEMA_PATH
    instance_file = instance_path or repo / LOCATOR_INSTANCE_PATH
    try:
        schema_bytes = schema_file.read_bytes()
        instance_bytes = instance_file.read_bytes()
    except OSError as error:
        reject("LOCATOR_AUTHORITY_MISSING", str(error))

    schema = strict_json_bytes(schema_bytes, "locatorSchema")
    instance = strict_json_bytes(instance_bytes, "locatorAuthority")
    if instance is None:
        reject("NULL_LOCATOR_AUTHORITY", str(instance_file))
    if not isinstance(schema, dict) or not isinstance(instance, dict):
        reject(
            "INVALID_LOCATOR_AUTHORITY_OBJECT",
            {"schemaType": type(schema).__name__, "instanceType": type(instance).__name__},
        )
    schema_sha = sha256_bytes(schema_bytes)
    instance_sha = sha256_bytes(instance_bytes)
    if schema_sha != LOCATOR_SCHEMA_SHA256:
        reject(
            "AUTHORITY_SCHEMA_SHA_MISMATCH",
            {"expected": LOCATOR_SCHEMA_SHA256, "actual": schema_sha},
        )
    if instance_sha != LOCATOR_INSTANCE_SHA256:
        reject(
            "AUTHORITY_INSTANCE_SHA_MISMATCH",
            {"expected": LOCATOR_INSTANCE_SHA256, "actual": instance_sha},
        )

    Draft202012Validator.check_schema(schema)
    errors = sorted(
        Draft202012Validator(schema).iter_errors(instance),
        key=lambda error: list(error.absolute_path),
    )
    if errors:
        error = errors[0]
        reject(
            "LOCATOR_SCHEMA_REJECTION",
            {"path": list(error.absolute_path), "message": error.message},
        )

    require_file_at_commit(
        repo, LOCATOR_AUTHORITY_COMMIT, LOCATOR_SCHEMA_PATH, LOCATOR_SCHEMA_SHA256
    )
    require_file_at_commit(
        repo,
        LOCATOR_AUTHORITY_COMMIT,
        LOCATOR_INSTANCE_PATH,
        LOCATOR_INSTANCE_SHA256,
    )
    require_ancestor(repo, LOCATOR_AUTHORITY_COMMIT, "HEAD", "locatorAuthority")

    source_stage = instance.get("sourceStageSchema")
    if source_stage != {
        "path": SOURCE_STAGE_SCHEMA_PATH,
        "version": 2,
        "sha256": SOURCE_STAGE_SCHEMA_SHA256,
    }:
        reject("SOURCE_STAGE_AUTHORITY_MISMATCH", source_stage)
    if sha256_file(repo / SOURCE_STAGE_SCHEMA_PATH) != SOURCE_STAGE_SCHEMA_SHA256:
        reject("SOURCE_STAGE_SCHEMA_SHA_MISMATCH", SOURCE_STAGE_SCHEMA_PATH)
    if (
        sha256_file(repo / SOURCE_STAGE_VALIDATOR_PATH)
        != SOURCE_STAGE_VALIDATOR_SHA256
    ):
        reject("SOURCE_STAGE_VALIDATOR_SHA_MISMATCH", SOURCE_STAGE_VALIDATOR_PATH)

    matches = [
        value
        for value in instance.get("directions", [])
        if isinstance(value, dict) and value.get("taskId") == TASK_ID
    ]
    if len(matches) != 1:
        reject("SOUTH_LOCATOR_CARDINALITY", len(matches))
    south = matches[0]
    expected = {
        "taskId": TASK_ID,
        "direction": DIRECTION,
        "branch": BRANCH,
        "evidenceRoot": EVIDENCE_ROOT,
        "packetPath": RESERVED_PACKET_PATH,
        "status": "reserved",
        "writer": "direction_cell",
        "creationPolicy": "exclusive_no_overwrite_nofollow",
    }
    if south != expected:
        reject("SOUTH_LOCATOR_MISMATCH", {"expected": expected, "actual": south})
    return {
        "schemaSha256": schema_sha,
        "instanceSha256": instance_sha,
        "south": south,
    }


def validate_candidate_identity(
    candidate: dict[str, Any],
    content_commit: str,
    destination: str,
) -> None:
    safe_relative_path(destination, "destination")
    if destination != RESERVED_PACKET_PATH:
        reject(
            "WRONG_PACKET_PATH",
            {"expected": RESERVED_PACKET_PATH, "actual": destination},
        )
    if candidate.get("stage") != "source_candidate":
        reject("WRONG_PACKET_STAGE", candidate.get("stage"))
    identity = candidate.get("identity")
    if not isinstance(identity, dict):
        reject("MISSING_PACKET_IDENTITY", identity)
    observed_direction = identity.get("direction")
    observed_task = identity.get("taskId")
    if observed_direction in {"east", "west", "north"} or observed_task in {
        "PLAY-027",
        "PLAY-079",
        "PLAY-081",
    }:
        reject(
            "SIBLING_SUBSTITUTION",
            {"taskId": observed_task, "direction": observed_direction},
        )
    if observed_direction != DIRECTION:
        reject("WRONG_DIRECTION", observed_direction)
    if observed_task != TASK_ID:
        reject("WRONG_TASK", observed_task)
    if identity.get("branch") != BRANCH:
        reject("WRONG_BRANCH", identity.get("branch"))
    if identity.get("sourceRoot") != SOURCE_ROOT:
        reject("WRONG_SOURCE_ROOT", identity.get("sourceRoot"))
    if identity.get("evidenceRoot") != EVIDENCE_ROOT:
        reject("WRONG_EVIDENCE_ROOT", identity.get("evidenceRoot"))
    safe_relative_path(identity["sourceRoot"], "identity.sourceRoot")
    safe_relative_path(identity["evidenceRoot"], "identity.evidenceRoot")

    lineage = candidate.get("lineage")
    completion = candidate.get("completion")
    if not isinstance(lineage, dict) or not isinstance(completion, dict):
        reject("MISSING_CONTENT_COMMIT_BINDING", None)
    bound = lineage.get("cellContentCommit")
    completed = completion.get("contentCommit")
    if bound != content_commit or completed != content_commit:
        reject(
            "CONTENT_COMMIT_MISMATCH",
            {
                "argument": content_commit,
                "lineage": bound,
                "completion": completed,
            },
        )
    receipt = completion.get("parallelExecutionReceipt")
    if not isinstance(receipt, dict) or receipt.get("path") != STRICT_RECEIPT_PATH:
        reject("STRICT_RECEIPT_PATH_MISMATCH", receipt)


def run_source_stage_validation(
    repo: Path,
    candidate_path: Path,
    candidate: dict[str, Any],
) -> dict[str, Any]:
    del candidate
    command = [
        sys.executable,
        str(repo / SOURCE_STAGE_VALIDATOR_PATH),
        str(candidate_path),
        "--repo-root",
        str(repo),
        "--schema",
        str(repo / SOURCE_STAGE_SCHEMA_PATH),
        "--expected-schema-sha256",
        SOURCE_STAGE_SCHEMA_SHA256,
    ]
    environment = dict(os.environ)
    environment["PYTHONDONTWRITEBYTECODE"] = "1"
    result = subprocess.run(
        command,
        check=False,
        capture_output=True,
        text=True,
        env=environment,
    )
    try:
        payload = strict_json_bytes(result.stdout.encode("utf-8"), "sourceStageResult")
    except PacketWriterRejected:
        reject(
            "SOURCE_STAGE_V2_REJECTED",
            {"returnCode": result.returncode, "stdout": result.stdout, "stderr": result.stderr},
        )
    if (
        result.returncode != 0
        or not isinstance(payload, dict)
        or payload.get("result") != "PASS"
        or payload.get("stage") != "source_candidate"
        or payload.get("taskId") != TASK_ID
        or payload.get("direction") != DIRECTION
    ):
        reject(
            "SOURCE_STAGE_V2_REJECTED",
            {
                "returnCode": result.returncode,
                "result": payload,
                "stderr": result.stderr.strip(),
            },
        )
    return payload


def run_strict_receipt_validation(
    repo: Path,
    receipt_path: Path,
    candidate: dict[str, Any],
) -> dict[str, Any]:
    expected = candidate["completion"]["parallelExecutionReceipt"]
    try:
        actual_sha = sha256_file(receipt_path)
    except PacketWriterRejected:
        reject("STRICT_PARALLEL_RECEIPT_REJECTED", str(receipt_path))
    if expected.get("sha256") != actual_sha:
        reject(
            "STRICT_PARALLEL_RECEIPT_REJECTED",
            {"expected": expected.get("sha256"), "actual": actual_sha},
        )
    command = [
        sys.executable,
        str(repo / STRICT_VALIDATOR_PATH),
        "--schema",
        str(repo / STRICT_SCHEMA_PATH),
        "--receipt",
        str(receipt_path),
    ]
    environment = dict(os.environ)
    environment["PYTHONDONTWRITEBYTECODE"] = "1"
    result = subprocess.run(
        command,
        check=False,
        capture_output=True,
        text=True,
        env=environment,
    )
    try:
        payload = strict_json_bytes(result.stdout.encode("utf-8"), "strictReceiptResult")
    except PacketWriterRejected:
        reject(
            "STRICT_PARALLEL_RECEIPT_REJECTED",
            {"returnCode": result.returncode, "stdout": result.stdout, "stderr": result.stderr},
        )
    if (
        result.returncode != 0
        or not isinstance(payload, dict)
        or payload.get("result") != "PASS"
        or payload.get("taskId") != TASK_ID
        or payload.get("direction") != DIRECTION
    ):
        reject(
            "STRICT_PARALLEL_RECEIPT_REJECTED",
            {
                "returnCode": result.returncode,
                "result": payload,
                "stderr": result.stderr.strip(),
            },
        )
    return payload


def prove_destination_safe(repo: Path, destination: str) -> dict[str, Any]:
    pure = safe_relative_path(destination, "destination")
    target = repo.joinpath(*pure.parts)
    parent = target.parent
    if parent != repo / EVIDENCE_ROOT:
        reject(
            "WRONG_PACKET_PARENT",
            {"expected": str(repo / EVIDENCE_ROOT), "actual": str(parent)},
        )

    current = repo
    for part in pure.parts[:-1]:
        current = current / part
        try:
            metadata = os.lstat(current)
        except FileNotFoundError:
            reject("MISSING_PACKET_PARENT", str(current))
        if stat.S_ISLNK(metadata.st_mode):
            reject("SYMLINK_REDIRECT", str(current))
        if not stat.S_ISDIR(metadata.st_mode):
            reject("PACKET_PARENT_NOT_DIRECTORY", str(current))

    try:
        metadata = os.lstat(target)
    except FileNotFoundError:
        metadata = None
    if metadata is not None:
        if stat.S_ISLNK(metadata.st_mode):
            reject("SYMLINK_REDIRECT", destination)
        reject("PREEXISTING_PACKET", destination)

    parent_metadata = os.stat(parent, follow_symlinks=False)
    return {
        "result": "PASS",
        "destination": destination,
        "parentDevice": parent_metadata.st_dev,
        "parentInode": parent_metadata.st_ino,
        "targetAbsent": True,
        "allExistingComponentsNoFollow": True,
        "exclusiveCreate": True,
        "openFlags": ["O_CREAT", "O_EXCL", "O_NOFOLLOW", "O_WRONLY"],
    }


def write_exclusive_nofollow(
    repo: Path,
    destination: str,
    content: bytes,
    proof: dict[str, Any],
) -> None:
    pure = safe_relative_path(destination, "destination")
    parent = repo.joinpath(*pure.parts[:-1])
    directory_flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0)
    directory_flags |= getattr(os, "O_NOFOLLOW", 0)
    parent_fd = os.open(parent, directory_flags)
    try:
        metadata = os.fstat(parent_fd)
        if (
            metadata.st_dev != proof["parentDevice"]
            or metadata.st_ino != proof["parentInode"]
        ):
            reject("PACKET_PARENT_CHANGED_AFTER_PROOF", destination)
        flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
        flags |= getattr(os, "O_NOFOLLOW", 0)
        try:
            packet_fd = os.open(pure.name, flags, 0o600, dir_fd=parent_fd)
        except FileExistsError:
            reject("PREEXISTING_PACKET", destination)
        except OSError as error:
            reject("PACKET_EXCLUSIVE_CREATE_FAILED", str(error))
        try:
            with os.fdopen(packet_fd, "wb", closefd=True) as handle:
                handle.write(content)
                handle.flush()
                os.fsync(handle.fileno())
        except Exception:
            try:
                os.unlink(pure.name, dir_fd=parent_fd)
            except OSError:
                pass
            raise
    finally:
        os.close(parent_fd)


def evaluate(
    *,
    repo: Path,
    candidate_path: Path,
    candidate_bytes: bytes,
    content_commit: str,
    strict_receipt_path: Path,
    destination: str = RESERVED_PACKET_PATH,
    write: bool = False,
    source_stage_runner: ValidationRunner | None = None,
    strict_runner: ValidationRunner | None = None,
) -> dict[str, Any]:
    authority = load_locator_authority(repo)
    candidate = strict_json_bytes(candidate_bytes, "candidatePacket")
    if not isinstance(candidate, dict):
        reject("INVALID_CANDIDATE_PACKET_OBJECT", type(candidate).__name__)
    content = require_commit(repo, content_commit, "contentCommit")
    validate_candidate_identity(candidate, content, destination)
    require_ancestor(repo, content, "HEAD", "contentCommit")
    actual_branch = git(repo, "branch", "--show-current")
    if actual_branch != BRANCH:
        reject("ACTUAL_BRANCH_MISMATCH", {"expected": BRANCH, "actual": actual_branch})

    source_runner = source_stage_runner or (
        lambda path, value: run_source_stage_validation(repo, path, value)
    )
    receipt_runner = strict_runner or (
        lambda path, value: run_strict_receipt_validation(repo, path, value)
    )
    source_stage_result = source_runner(candidate_path, candidate)
    if (
        not isinstance(source_stage_result, dict)
        or source_stage_result.get("result") != "PASS"
        or source_stage_result.get("stage") != "source_candidate"
        or source_stage_result.get("taskId") != TASK_ID
        or source_stage_result.get("direction") != DIRECTION
        or source_stage_result.get("contentCommit") != content
    ):
        reject("SOURCE_STAGE_V2_REJECTED", source_stage_result)

    strict_result = receipt_runner(strict_receipt_path, candidate)
    if (
        not isinstance(strict_result, dict)
        or strict_result.get("result") != "PASS"
        or strict_result.get("taskId") != TASK_ID
        or strict_result.get("direction") != DIRECTION
    ):
        reject("STRICT_PARALLEL_RECEIPT_REJECTED", strict_result)

    proof = prove_destination_safe(repo, destination)
    packet_written = False
    if write:
        status = git(repo, "status", "--porcelain")
        if status:
            reject("WORKTREE_DIRTY_BEFORE_PACKET_WRITE", status)
        write_exclusive_nofollow(repo, destination, candidate_bytes, proof)
        packet_written = True

    return {
        "schema": "citysim.play-080.source-candidate-packet-writer-boundary.v1",
        "result": "PASS",
        "mode": "write" if write else "dry_run",
        "taskId": TASK_ID,
        "direction": DIRECTION,
        "branch": BRANCH,
        "contentCommit": content,
        "candidatePacketSha256": sha256_bytes(candidate_bytes),
        "locatorAuthority": {
            "commit": LOCATOR_AUTHORITY_COMMIT,
            "schemaPath": LOCATOR_SCHEMA_PATH,
            "schemaSha256": authority["schemaSha256"],
            "instancePath": LOCATOR_INSTANCE_PATH,
            "instanceSha256": authority["instanceSha256"],
            "reservedPacketPath": authority["south"]["packetPath"],
        },
        "sourceStageV2": source_stage_result,
        "strictParallelReceipt": strict_result,
        "pathProof": proof,
        "packetWritten": packet_written,
        "zeroActivity": {
            "dccProcessInvocations": 0,
            "renderApiCalls": 0,
            "imageGenInvocations": 0,
            "normalizationInvocations": 0,
            "contactSheetInvocations": 0,
            "pixelFilesCreated": 0,
        },
        "authorityBoundary": {
            "sourceReady": False,
            "integrationAdmitted": False,
            "rendererQuarantined": False,
            "productionSelected": False,
            "shipping": False,
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--content-commit", required=True)
    parser.add_argument(
        "--strict-receipt",
        type=Path,
        default=Path(STRICT_RECEIPT_PATH),
    )
    parser.add_argument(
        "--destination",
        default=RESERVED_PACKET_PATH,
        help="Must equal the Integration-reserved South packet path.",
    )
    parser.add_argument(
        "--write",
        action="store_true",
        help="Create the reserved packet only after every gate passes.",
    )
    arguments = parser.parse_args()
    candidate_path = arguments.candidate.resolve()
    strict_path = (
        arguments.strict_receipt
        if arguments.strict_receipt.is_absolute()
        else REPOSITORY_ROOT / arguments.strict_receipt
    )
    try:
        candidate_bytes = candidate_path.read_bytes()
        result = evaluate(
            repo=REPOSITORY_ROOT,
            candidate_path=candidate_path,
            candidate_bytes=candidate_bytes,
            content_commit=arguments.content_commit,
            strict_receipt_path=strict_path.resolve(),
            destination=arguments.destination,
            write=arguments.write,
            source_stage_runner=lambda path, candidate: run_source_stage_validation(
                REPOSITORY_ROOT, path, candidate
            ),
            strict_runner=lambda path, candidate: run_strict_receipt_validation(
                REPOSITORY_ROOT, path, candidate
            ),
        )
    except (OSError, PacketWriterRejected) as error:
        if isinstance(error, PacketWriterRejected):
            code, detail = error.code, error.detail
        else:
            code, detail = "CANDIDATE_READ_FAILURE", str(error)
        print(
            json.dumps(
                {
                    "result": "REJECTED",
                    "code": code,
                    "detail": detail,
                    "packetWritten": False,
                },
                sort_keys=True,
            )
        )
        return 2
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
