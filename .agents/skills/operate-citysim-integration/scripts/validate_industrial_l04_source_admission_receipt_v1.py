#!/usr/bin/env python3
"""Validate one Integration-owned Industrial L4 source-admission receipt."""

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
from typing import Any, Callable, Iterable, Mapping

from jsonschema import Draft202012Validator
from jsonschema.exceptions import SchemaError


SCHEMA_ID = "citysim://integration/industrial-l04-source-admission-receipt-v1"
SCHEMA_PATH = (
    "docs/production/evidence/INTEGRATION/"
    "industrial-l04-source-admission-receipt-schema-v1.json"
)
ADMISSION_SCHEMA_SHA256 = (
    "08ad183eb90dc8eb14567a432c00841b010f90f8d8e4d359b60d4735c4ca4f66"
)
LEDGER_PATH = (
    "docs/production/evidence/INTEGRATION/"
    "WORLD_ART_PARALLEL_BATCH_LEDGER.json"
)
SOURCE_STAGE_SCHEMA_PATH = (
    "docs/production/evidence/INTEGRATION/"
    "industrial-l04-source-stage-handoff-schema-v2.json"
)
SOURCE_STAGE_SCHEMA_SHA256 = (
    "85f6a2824c273a1e63354df79a97e5a59c2909a68771613b325664d649ac53ec"
)
SEMANTIC_VALIDATOR_PATH = (
    "Native/CitySimNative/WorldArt/Shared/"
    "validate_source_stage_handoff_v2.py"
)
SEMANTIC_VALIDATOR_SHA256 = (
    "7a0613af9998a222a583a70930ce3afc5ec1902793f03201f899a2bb4129f340"
)
DIRECTIONS = ("north", "east", "south", "west")
SOURCE_BRANCHES = {
    "north": "codex/citysim-world-art",
    "east": "codex/citysim-world-art-east",
    "south": "codex/citysim-world-art-south",
    "west": "codex/citysim-world-art-west",
}
SEMANTIC_RECEIPT_ROOT = PurePosixPath(
    "docs/production/evidence/INTEGRATION/"
    "industrial-l04-semantic-validations-v2"
)
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")
RECEIPT_KEYS = frozenset(
    {
        "schemaVersion",
        "disposition",
        "integrationCommit",
        "sourceContext",
        "direction",
        "logicalID",
        "familyContract",
        "appearanceLock",
        "sourceProductionProfile",
        "sourceStageSchema",
        "workerPacket",
        "contentCommit",
        "admittedRaw",
        "decodedRgbaSha256",
        "semanticValidator",
        "semanticValidationReceipt",
        "semanticValidationResult",
        "independentTechnicalReview",
        "independentTechnicalDisposition",
        "literalScaleReview",
        "literalScaleDisposition",
        "sharedLedgerRevision",
        "rendererQuarantined",
        "productionSelected",
        "shippingActivated",
    }
)


class AdmissionError(RuntimeError):
    """A fail-closed source-admission validation error."""

    def __init__(self, code: str, detail: str = "") -> None:
        self.code = code
        super().__init__(f"{code}: {detail}" if detail else code)


def fail(code: str, detail: Any = "") -> None:
    raise AdmissionError(code, str(detail))


def strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            fail("DUPLICATE_JSON_KEY", key)
        result[key] = value
    return result


def strict_json_bytes(data: bytes, label: str) -> Any:
    try:
        return json.loads(data.decode("utf-8"), object_pairs_hook=strict_object)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        fail("INVALID_JSON", f"{label}: {error}")


def strict_json_file(path: Path, label: str) -> Any:
    return strict_json_bytes(path.read_bytes(), label)


def require_mapping(value: Any, label: str) -> Mapping[str, Any]:
    if not isinstance(value, Mapping):
        fail("EXPECTED_OBJECT", label)
    return value


def require_exact_keys(
    value: Mapping[str, Any],
    expected: Iterable[str],
    label: str,
) -> None:
    expected_set = frozenset(expected)
    actual = frozenset(value)
    if actual != expected_set:
        fail(
            "KEY_SET_MISMATCH",
            f"{label}: missing={sorted(expected_set - actual)!r} "
            f"unknown={sorted(actual - expected_set)!r}",
        )


def require_sha256(value: Any, label: str) -> str:
    if not isinstance(value, str) or not SHA256_RE.fullmatch(value):
        fail("INVALID_SHA256", label)
    return value


def require_commit(value: Any, label: str) -> str:
    if not isinstance(value, str) or not COMMIT_RE.fullmatch(value):
        fail("INVALID_COMMIT", label)
    return value


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical_relative_path(value: Any, label: str) -> PurePosixPath:
    if not isinstance(value, str) or not value:
        fail("INVALID_PATH", label)
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or "." in path.parts:
        fail("UNSAFE_PATH", f"{label}: {value!r}")
    allowed = (
        ("Native", "CitySimNative", "WorldArt"),
        ("docs", "production", "decisions"),
        ("docs", "production", "evidence"),
    )
    if not any(path.parts[: len(prefix)] == prefix for prefix in allowed):
        fail("OUTSIDE_ALLOWED_ROOT", f"{label}: {value!r}")
    return path


def safe_regular_file(repo: Path, value: Any, label: str) -> Path:
    relative = canonical_relative_path(value, label)
    current = repo
    for component in relative.parts:
        current = current / component
        try:
            mode = os.lstat(current).st_mode
        except FileNotFoundError:
            fail("MISSING_FILE", f"{label}: {relative}")
        if stat.S_ISLNK(mode):
            fail("SYMLINK_FORBIDDEN", f"{label}: {current}")
    if not stat.S_ISREG(os.lstat(current).st_mode):
        fail("NON_REGULAR_FILE", f"{label}: {current}")
    resolved = current.resolve(strict=True)
    try:
        resolved.relative_to(repo)
    except ValueError:
        fail("PATH_ESCAPE", f"{label}: {resolved}")
    return resolved


def require_path_under(value: Any, root: PurePosixPath, label: str) -> None:
    relative = canonical_relative_path(value, label)
    if relative.parts[: len(root.parts)] != root.parts:
        fail("PATH_ROOT_MISMATCH", f"{label}: {relative} not under {root}")


def verify_artifact(
    repo: Path,
    descriptor: Any,
    label: str,
    *,
    review: bool = False,
    committed: bool = False,
) -> tuple[Path, Mapping[str, Any]]:
    artifact = require_mapping(descriptor, label)
    if review:
        keys = ("path", "sha256", "disposition")
    elif committed:
        keys = ("path", "commit", "sha256")
    else:
        keys = ("path", "sha256")
    require_exact_keys(artifact, keys, label)
    path = safe_regular_file(repo, artifact["path"], f"{label}.path")
    expected = require_sha256(artifact["sha256"], f"{label}.sha256")
    actual = sha256_bytes(path.read_bytes())
    if actual != expected:
        fail("ARTIFACT_HASH_MISMATCH", f"{label}: {expected} != {actual}")
    return path, artifact


def git_output(repo: Path, *args: str) -> bytes:
    result = subprocess.run(
        ["git", "-C", str(repo), *args],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode:
        fail("GIT_FAILURE", result.stderr.decode("utf-8", errors="replace").strip())
    return result.stdout


def require_blob_hash(
    repo: Path,
    commit: str,
    path: Any,
    expected_sha256: str,
    label: str,
) -> None:
    relative = canonical_relative_path(path, f"{label}.path")
    blob = git_output(repo, "show", f"{commit}:{relative.as_posix()}")
    actual = sha256_bytes(blob)
    if actual != expected_sha256:
        fail("COMMITTED_BLOB_HASH_MISMATCH", f"{label}: {actual}")


def require_commit_resolves(repo: Path, commit: str, label: str) -> None:
    result = subprocess.run(
        ["git", "-C", str(repo), "cat-file", "-e", f"{commit}^{{commit}}"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if result.returncode:
        fail("UNRESOLVED_COMMIT", label)


def require_ancestor(repo: Path, ancestor: str, descendant: str, label: str) -> None:
    result = subprocess.run(
        ["git", "-C", str(repo), "merge-base", "--is-ancestor", ancestor, descendant],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if result.returncode:
        fail("ANCESTRY_MISMATCH", label)


def nested(value: Mapping[str, Any], *keys: str) -> Any:
    current: Any = value
    for key in keys:
        current = require_mapping(current, ".".join(keys))
        if key not in current:
            fail("MISSING_PACKET_FIELD", ".".join(keys))
        current = current[key]
    return current


def validate_json_schema(
    schema: Mapping[str, Any],
    instance: Mapping[str, Any],
    label: str,
) -> None:
    try:
        Draft202012Validator.check_schema(schema)
    except SchemaError as error:
        fail("INVALID_JSON_SCHEMA", f"{label}: {error.message}")
    errors = sorted(
        Draft202012Validator(schema).iter_errors(instance),
        key=lambda error: tuple(str(part) for part in error.absolute_path),
    )
    if errors:
        first = errors[0]
        location = ".".join(str(part) for part in first.absolute_path) or "<root>"
        fail(
            "JSON_SCHEMA_VALIDATION_FAILED",
            f"{label}.{location}: {first.message}; total={len(errors)}",
        )


def run_semantic_validator(
    repo: Path,
    packet_path: Path,
    schema_path: Path,
) -> Mapping[str, Any]:
    result = subprocess.run(
        [
            sys.executable,
            str(repo / SEMANTIC_VALIDATOR_PATH),
            str(packet_path),
            "--repo-root",
            str(repo),
            "--schema",
            str(schema_path),
            "--expected-schema-sha256",
            SOURCE_STAGE_SCHEMA_SHA256,
        ],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode:
        fail(
            "SEMANTIC_VALIDATOR_FAILED",
            result.stdout.decode("utf-8", errors="replace").strip()
            or result.stderr.decode("utf-8", errors="replace").strip(),
        )
    output = require_mapping(
        strict_json_bytes(result.stdout, "semanticValidator.stdout"),
        "semanticValidator.stdout",
    )
    if output.get("result") != "PASS":
        fail("SEMANTIC_VALIDATOR_NOT_PASS")
    return output


def expected_review_binding(
    data: Any,
    *,
    expected_disposition: str,
    direction: str,
    logical_id: str,
    packet_sha256: str,
    content_commit: str,
    decoded_sha256: str,
    label: str,
) -> None:
    review = require_mapping(data, label)
    expected = {
        "disposition": expected_disposition,
        "direction": direction,
        "logicalID": logical_id,
        "workerPacketSha256": packet_sha256,
        "contentCommit": content_commit,
        "decodedRgbaSha256": decoded_sha256,
    }
    for key, value in expected.items():
        if review.get(key) != value:
            fail("REVIEW_BINDING_MISMATCH", f"{label}.{key}")


def validate_receipt(
    repo: Path,
    receipt: Mapping[str, Any],
    *,
    source_repo: Path | None = None,
    verify_git: bool = True,
    semantic_runner: Callable[[Path, Path, Path], Mapping[str, Any]] = (
        run_semantic_validator
    ),
) -> dict[str, Any]:
    repo = repo.resolve()
    source_repo = (source_repo or repo).resolve()
    admission_schema_path = safe_regular_file(repo, SCHEMA_PATH, "admissionSchema")
    admission_schema_bytes = admission_schema_path.read_bytes()
    if sha256_bytes(admission_schema_bytes) != ADMISSION_SCHEMA_SHA256:
        fail("ADMISSION_SCHEMA_HASH_MISMATCH")
    admission_schema = require_mapping(
        strict_json_bytes(admission_schema_bytes, "admissionSchema"),
        "admissionSchema",
    )
    validate_json_schema(admission_schema, receipt, "receipt")
    require_exact_keys(receipt, RECEIPT_KEYS, "receipt")
    if receipt["schemaVersion"] != 1:
        fail("SCHEMA_VERSION_MISMATCH")
    if receipt["disposition"] != "integration_source_admitted":
        fail("DISPOSITION_MISMATCH")

    direction = receipt["direction"]
    if direction not in DIRECTIONS:
        fail("DIRECTION_MISMATCH", direction)
    logical_id = f"industrial_l04_v0_{direction}"
    if receipt["logicalID"] != logical_id:
        fail("LOGICAL_ID_MISMATCH")
    integration_commit = require_commit(
        receipt["integrationCommit"], "integrationCommit"
    )
    content_commit = require_commit(receipt["contentCommit"], "contentCommit")
    source_context = require_mapping(receipt["sourceContext"], "sourceContext")
    require_exact_keys(
        source_context,
        ("branch", "head", "cleanState"),
        "sourceContext",
    )
    source_head = require_commit(source_context["head"], "sourceContext.head")
    if (
        source_context["branch"] != SOURCE_BRANCHES[direction]
        or source_context["cleanState"] != "clean"
    ):
        fail("SOURCE_CONTEXT_MISMATCH")
    decoded_sha256 = require_sha256(
        receipt["decodedRgbaSha256"], "decodedRgbaSha256"
    )

    if receipt["semanticValidationResult"] != "PASS":
        fail("SEMANTIC_VALIDATION_NOT_PASS")
    if receipt["independentTechnicalDisposition"] != "ACCEPT":
        fail("TECHNICAL_REVIEW_NOT_ACCEPT")
    if receipt["literalScaleDisposition"] != "ACCEPT":
        fail("LITERAL_REVIEW_NOT_ACCEPT")
    for field in ("rendererQuarantined", "productionSelected", "shippingActivated"):
        if receipt[field] is not False:
            fail("AUTHORITY_ESCALATION", field)

    packet_path, packet_artifact = verify_artifact(
        source_repo, receipt["workerPacket"], "workerPacket"
    )
    packet_sha256 = packet_artifact["sha256"]
    packet = require_mapping(
        strict_json_file(packet_path, "workerPacket"), "workerPacket"
    )
    if packet.get("schemaVersion") != 2 or packet.get("stage") != "source_candidate":
        fail("PACKET_STAGE_MISMATCH")
    identity = require_mapping(packet.get("identity"), "packet.identity")
    if (
        identity.get("direction") != direction
        or identity.get("logicalID") != logical_id
        or identity.get("family") != "industrial"
        or identity.get("level") != 4
        or identity.get("variant") != 0
        or identity.get("orientationTransform") != "none"
        or identity.get("fallbackSourceKey") is not None
    ):
        fail("PACKET_IDENTITY_MISMATCH")
    if packet.get("candidateReadyForIndependentReview") is not True:
        fail("PACKET_NOT_REVIEW_READY")
    for field in (
        "sourceReady",
        "integrationAdmitted",
        "rendererQuarantined",
        "productionSelected",
    ):
        if packet.get(field) is not False:
            fail("WORKER_SELF_ADMISSION", field)

    completion = require_mapping(packet.get("completion"), "packet.completion")
    if completion.get("contentCommit") != content_commit:
        fail("CONTENT_COMMIT_MISMATCH")
    source = require_mapping(completion.get("source"), "packet.completion.source")
    if (
        source.get("decodedRgbaSha256") != decoded_sha256
        or source.get("fallbackSourceKey") is not None
    ):
        fail("DECODED_SOURCE_MISMATCH")
    selected = require_mapping(
        completion.get("selectedSource"), "packet.completion.selectedSource"
    )
    if selected.get("decodedRgbaSha256") != decoded_sha256:
        fail("SELECTED_SOURCE_DECODED_MISMATCH")

    admitted_raw_path, admitted_raw = verify_artifact(
        source_repo, receipt["admittedRaw"], "admittedRaw"
    )
    if (
        admitted_raw["path"] != selected.get("path")
        or admitted_raw["sha256"] != selected.get("sha256")
        or admitted_raw_path != safe_regular_file(
            source_repo,
            selected.get("path"),
            "packet.completion.selectedSource.path",
        )
    ):
        fail("ADMITTED_RAW_MISMATCH")

    family_path, family = verify_artifact(
        repo, receipt["familyContract"], "familyContract"
    )
    del family_path
    authorities = require_mapping(packet.get("authorities"), "packet.authorities")
    if dict(family) != dict(
        require_mapping(authorities.get("contract010"), "packet.authorities.contract010")
    ):
        fail("FAMILY_CONTRACT_MISMATCH")

    appearance = require_mapping(receipt["appearanceLock"], "appearanceLock")
    require_exact_keys(
        appearance,
        (
            "documentPath",
            "commit",
            "documentSha256",
            "northProcessASourceSha256",
            "northProcessADecodedRgbaSha256",
        ),
        "appearanceLock",
    )
    appearance_path = safe_regular_file(
        repo, appearance["documentPath"], "appearanceLock.documentPath"
    )
    if sha256_bytes(appearance_path.read_bytes()) != require_sha256(
        appearance["documentSha256"], "appearanceLock.documentSha256"
    ):
        fail("APPEARANCE_LOCK_HASH_MISMATCH")
    require_commit(appearance["commit"], "appearanceLock.commit")
    require_sha256(
        appearance["northProcessASourceSha256"],
        "appearanceLock.northProcessASourceSha256",
    )
    require_sha256(
        appearance["northProcessADecodedRgbaSha256"],
        "appearanceLock.northProcessADecodedRgbaSha256",
    )
    if dict(appearance) != dict(
        require_mapping(authorities.get("appearanceLock"), "packet.authorities.appearanceLock")
    ):
        fail("APPEARANCE_LOCK_MISMATCH")

    _, profile = verify_artifact(
        repo,
        receipt["sourceProductionProfile"],
        "sourceProductionProfile",
        committed=True,
    )
    require_commit(profile.get("commit"), "sourceProductionProfile.commit")
    if dict(profile) != dict(
        require_mapping(
            authorities.get("sourceProductionProfile"),
            "packet.authorities.sourceProductionProfile",
        )
    ):
        fail("SOURCE_PROFILE_MISMATCH")

    stage_schema = require_mapping(receipt["sourceStageSchema"], "sourceStageSchema")
    require_exact_keys(stage_schema, ("path", "version", "sha256"), "sourceStageSchema")
    if stage_schema != {
        "path": SOURCE_STAGE_SCHEMA_PATH,
        "version": 2,
        "sha256": SOURCE_STAGE_SCHEMA_SHA256,
    }:
        fail("SOURCE_STAGE_SCHEMA_DRIFT")
    schema_file = safe_regular_file(
        source_repo, stage_schema["path"], "sourceStageSchema.path"
    )
    if sha256_bytes(schema_file.read_bytes()) != SOURCE_STAGE_SCHEMA_SHA256:
        fail("SOURCE_STAGE_SCHEMA_HASH_MISMATCH")
    source_stage_schema = require_mapping(
        strict_json_file(schema_file, "sourceStageSchema"),
        "sourceStageSchema",
    )
    validate_json_schema(source_stage_schema, packet, "workerPacket")

    _, semantic_validator = verify_artifact(
        source_repo, receipt["semanticValidator"], "semanticValidator"
    )
    if semantic_validator != {
        "path": SEMANTIC_VALIDATOR_PATH,
        "sha256": SEMANTIC_VALIDATOR_SHA256,
    }:
        fail("SEMANTIC_VALIDATOR_DRIFT")
    if dict(semantic_validator) != dict(
        require_mapping(
            authorities.get("semanticValidator"),
            "packet.authorities.semanticValidator",
        )
    ):
        fail("SEMANTIC_VALIDATOR_PACKET_MISMATCH")

    semantic_path, semantic_review = verify_artifact(
        repo,
        receipt["semanticValidationReceipt"],
        "semanticValidationReceipt",
        review=True,
    )
    require_path_under(
        semantic_review["path"],
        SEMANTIC_RECEIPT_ROOT,
        "semanticValidationReceipt.path",
    )
    packet_validation = require_mapping(
        completion.get("validation"), "packet.completion.validation"
    )
    if packet_validation.get("result") != "PASS":
        fail("WORKER_VALIDATION_NOT_PASS")
    if semantic_review["disposition"] != "PASS":
        fail("SEMANTIC_RECEIPT_DISPOSITION_MISMATCH")
    semantic_data = require_mapping(
        strict_json_file(semantic_path, "semanticValidationReceipt"),
        "semanticValidationReceipt",
    )
    semantic_result = require_mapping(
        semantic_runner(source_repo, packet_path, schema_file),
        "semanticValidator.result",
    )
    if dict(semantic_data) != dict(semantic_result):
        fail("SEMANTIC_RECEIPT_EXECUTION_MISMATCH")
    if (
        semantic_result.get("schema")
        != "citysim://integration/industrial-l04-source-stage-handoff-v2"
        or semantic_result.get("result") != "PASS"
        or semantic_result.get("stage") != "source_candidate"
        or semantic_result.get("taskId") != identity.get("taskId")
        or semantic_result.get("direction") != direction
        or semantic_result.get("contentCommit") != content_commit
    ):
        fail("SEMANTIC_RECEIPT_BINDING_MISMATCH")

    technical_path, technical = verify_artifact(
        repo,
        receipt["independentTechnicalReview"],
        "independentTechnicalReview",
        review=True,
    )
    if technical["disposition"] != "ACCEPT":
        fail("TECHNICAL_REVIEW_DESCRIPTOR_MISMATCH")
    expected_review_binding(
        strict_json_file(technical_path, "independentTechnicalReview"),
        expected_disposition="ACCEPT",
        direction=direction,
        logical_id=logical_id,
        packet_sha256=packet_sha256,
        content_commit=content_commit,
        decoded_sha256=decoded_sha256,
        label="independentTechnicalReview",
    )

    literal_path, literal = verify_artifact(
        repo,
        receipt["literalScaleReview"],
        "literalScaleReview",
        review=True,
    )
    if literal["disposition"] != "ACCEPT":
        fail("LITERAL_REVIEW_DESCRIPTOR_MISMATCH")
    expected_review_binding(
        strict_json_file(literal_path, "literalScaleReview"),
        expected_disposition="ACCEPT",
        direction=direction,
        logical_id=logical_id,
        packet_sha256=packet_sha256,
        content_commit=content_commit,
        decoded_sha256=decoded_sha256,
        label="literalScaleReview",
    )

    ledger = require_mapping(receipt["sharedLedgerRevision"], "sharedLedgerRevision")
    require_exact_keys(
        ledger,
        ("path", "commit", "sha256", "batch", "directionState"),
        "sharedLedgerRevision",
    )
    if (
        ledger["path"] != LEDGER_PATH
        or ledger["batch"] != "industrial_l04_directional_family"
        or ledger["directionState"] != "integration_admitted"
    ):
        fail("LEDGER_BINDING_MISMATCH")
    ledger_commit = require_commit(ledger["commit"], "sharedLedgerRevision.commit")
    ledger_sha256 = require_sha256(ledger["sha256"], "sharedLedgerRevision.sha256")

    if verify_git:
        for commit, label in (
            (integration_commit, "integrationCommit"),
            (content_commit, "contentCommit"),
            (appearance["commit"], "appearanceLock.commit"),
            (profile["commit"], "sourceProductionProfile.commit"),
            (ledger_commit, "sharedLedgerRevision.commit"),
            (source_head, "sourceContext.head"),
        ):
            require_commit_resolves(repo, commit, label)
        require_ancestor(
            repo,
            integration_commit,
            ledger_commit,
            "integrationCommit -> sharedLedgerRevision.commit",
        )
        require_ancestor(
            source_repo,
            content_commit,
            source_head,
            "contentCommit -> sourceContext.head",
        )
        branch = git_output(
            source_repo, "branch", "--show-current"
        ).decode().strip()
        live_head = git_output(source_repo, "rev-parse", "HEAD").decode().strip()
        live_status = git_output(
            source_repo, "status", "--porcelain=v1", "--untracked-files=all"
        ).decode()
        if branch != source_context["branch"]:
            fail("SOURCE_BRANCH_MISMATCH", f"{branch!r}")
        if live_head != source_head:
            fail("SOURCE_HEAD_MISMATCH", f"{live_head} != {source_head}")
        if live_status:
            fail("SOURCE_WORKTREE_DIRTY")
        require_blob_hash(
            source_repo,
            source_head,
            packet_artifact["path"],
            packet_artifact["sha256"],
            "workerPacket",
        )
        head_commit = git_output(repo, "rev-parse", "HEAD").decode().strip()
        require_commit(head_commit, "HEAD")
        require_ancestor(
            repo,
            ledger_commit,
            head_commit,
            "sharedLedgerRevision.commit -> HEAD",
        )
        require_blob_hash(
            repo,
            integration_commit,
            family["path"],
            family["sha256"],
            "familyContract",
        )
        require_blob_hash(
            repo,
            appearance["commit"],
            appearance["documentPath"],
            appearance["documentSha256"],
            "appearanceLock",
        )
        require_blob_hash(
            repo,
            profile["commit"],
            profile["path"],
            profile["sha256"],
            "sourceProductionProfile",
        )
        require_blob_hash(
            repo,
            integration_commit,
            stage_schema["path"],
            stage_schema["sha256"],
            "sourceStageSchema",
        )
        require_blob_hash(
            repo,
            integration_commit,
            semantic_validator["path"],
            semantic_validator["sha256"],
            "semanticValidator",
        )
        ledger_bytes = git_output(repo, "show", f"{ledger_commit}:{LEDGER_PATH}")
        if sha256_bytes(ledger_bytes) != ledger_sha256:
            fail("LEDGER_BLOB_HASH_MISMATCH")
        ledger_data = require_mapping(
            strict_json_bytes(ledger_bytes, "sharedLedgerRevision"),
            "sharedLedgerRevision",
        )
        if ledger_data.get("batch") != ledger["batch"]:
            fail("LEDGER_BATCH_MISMATCH")
        cells = ledger_data.get("cells")
        if not isinstance(cells, list):
            fail("LEDGER_CELLS_MISSING")
        matching = [
            cell
            for cell in cells
            if isinstance(cell, Mapping) and cell.get("direction") == direction
        ]
        if len(matching) != 1:
            fail("LEDGER_DIRECTION_CARDINALITY")
        cell = matching[0]
        if (
            cell.get("state") != "integration_admitted"
            or cell.get("admittedContentCommit") != content_commit
            or cell.get("admittedPacketSha256") != packet_sha256
            or cell.get("admittedRawSha256") != admitted_raw["sha256"]
        ):
            fail("LEDGER_DIRECTION_ADMISSION_MISMATCH")

    return {
        "schema": SCHEMA_ID,
        "result": "PASS",
        "direction": direction,
        "logicalID": logical_id,
        "contentCommit": content_commit,
        "workerPacketSha256": packet_sha256,
        "admittedRawSha256": admitted_raw["sha256"],
        "decodedRgbaSha256": decoded_sha256,
        "rendererQuarantined": False,
        "productionSelected": False,
        "shippingActivated": False,
    }


def validate_schema_publication(repo: Path, schema_path: Path) -> dict[str, Any]:
    repo = repo.resolve()
    schema_path = schema_path.resolve()
    expected_path = safe_regular_file(repo, SCHEMA_PATH, "schema")
    if schema_path != expected_path:
        fail("SCHEMA_PATH_MISMATCH", schema_path)
    schema_bytes = schema_path.read_bytes()
    actual_schema_sha256 = sha256_bytes(schema_bytes)
    if actual_schema_sha256 != ADMISSION_SCHEMA_SHA256:
        fail(
            "ADMISSION_SCHEMA_HASH_MISMATCH",
            f"{actual_schema_sha256} != {ADMISSION_SCHEMA_SHA256}",
        )
    schema = require_mapping(strict_json_bytes(schema_bytes, "schema"), "schema")
    try:
        Draft202012Validator.check_schema(schema)
    except SchemaError as error:
        fail("INVALID_JSON_SCHEMA", error.message)
    if schema.get("$id") != SCHEMA_ID:
        fail("SCHEMA_ID_MISMATCH")
    if schema.get("additionalProperties") is not False:
        fail("SCHEMA_NOT_CLOSED")
    required = schema.get("required")
    if not isinstance(required, list) or frozenset(required) != RECEIPT_KEYS:
        fail("SCHEMA_REQUIRED_SET_MISMATCH")
    properties = require_mapping(schema.get("properties"), "schema.properties")
    if frozenset(properties) != RECEIPT_KEYS:
        fail("SCHEMA_PROPERTY_SET_MISMATCH")
    admissions_root = (
        repo
        / "docs/production/evidence/INTEGRATION/"
        "industrial-l04-source-admissions-v1"
    )
    existing_receipts = (
        sorted(admissions_root.glob("*.json")) if admissions_root.exists() else []
    )
    if existing_receipts:
        fail("UNAUTHORIZED_LIVE_RECEIPT_PRESENT", existing_receipts[0])
    return {
        "schema": SCHEMA_ID,
        "result": "PASS_PUBLICATION_ONLY",
        "liveReceiptCount": 0,
        "appearanceLockRequired": True,
        "sourceProductionProfileRequired": True,
        "admissionSchemaSha256": ADMISSION_SCHEMA_SHA256,
        "sourceAdmitted": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repository-root",
        type=Path,
        default=Path(__file__).resolve().parents[4],
    )
    parser.add_argument("--receipt")
    parser.add_argument("--source-worktree", type=Path)
    parser.add_argument(
        "--schema",
        default=SCHEMA_PATH,
    )
    parser.add_argument("--publication-check", action="store_true")
    args = parser.parse_args()
    repo = args.repository_root.resolve()
    try:
        if args.schema != SCHEMA_PATH:
            fail("SCHEMA_PATH_MISMATCH", args.schema)
        schema_path = safe_regular_file(repo, args.schema, "schema")
        if args.publication_check:
            result = validate_schema_publication(repo, schema_path)
        else:
            if args.receipt is None:
                fail("RECEIPT_REQUIRED")
            if args.source_worktree is None:
                fail("SOURCE_WORKTREE_REQUIRED")
            if not args.source_worktree.is_absolute():
                fail("SOURCE_WORKTREE_NOT_ABSOLUTE", args.source_worktree)
            try:
                source_mode = os.lstat(args.source_worktree).st_mode
            except FileNotFoundError:
                fail("SOURCE_WORKTREE_MISSING", args.source_worktree)
            if stat.S_ISLNK(source_mode) or not stat.S_ISDIR(source_mode):
                fail("SOURCE_WORKTREE_INVALID", args.source_worktree)
            source_repo = args.source_worktree.resolve(strict=True)
            receipt_relative = canonical_relative_path(args.receipt, "receipt")
            receipt_root = PurePosixPath(
                "docs/production/evidence/INTEGRATION/"
                "industrial-l04-source-admissions-v1"
            )
            if receipt_relative.parent != receipt_root:
                fail("RECEIPT_PATH_MISMATCH", receipt_relative)
            receipt_path = safe_regular_file(repo, args.receipt, "receipt")
            receipt = require_mapping(
                strict_json_file(receipt_path, "receipt"),
                "receipt",
            )
            result = validate_receipt(
                repo,
                receipt,
                source_repo=source_repo,
            )
    except (AdmissionError, OSError) as error:
        print(
            json.dumps(
                {"schema": SCHEMA_ID, "result": "FAIL", "error": str(error)},
                sort_keys=True,
            )
        )
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
