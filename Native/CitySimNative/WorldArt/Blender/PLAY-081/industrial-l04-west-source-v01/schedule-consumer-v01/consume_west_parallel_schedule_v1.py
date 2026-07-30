#!/usr/bin/env python3
"""Fail-closed PLAY-081 West consumer for future Integration schedules.

This adapter validates authority and future schedule/grant identities only. It
does not expose a child-process, DCC, renderer, normalization, or pixel API.
The only executable downstream identity it may describe is the approved
high-level West orchestrator.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
from typing import Any


SOURCE_ROOT = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-081/"
    "industrial-l04-west-source-v01"
)
CONSUMER_ROOT = f"{SOURCE_ROOT}/schedule-consumer-v01"
DEFAULT_CONTRACT = f"{CONSUMER_ROOT}/WEST-SCHEDULE-CONSUMER-CONTRACT-V1.json"
INTEGRATION_PREFIX = "docs/production/evidence/INTEGRATION/"
HEX_40 = re.compile(r"^[0-9a-f]{40}$")
HEX_64 = re.compile(r"^[0-9a-f]{64}$")
PROCESS_IDS = ("A", "B", "C")
ZERO_ACTIVITY = {
    "childProcessesStarted": 0,
    "blenderProcessLaunches": 0,
    "blenderRenderApiCalls": 0,
    "dccInvocations": 0,
    "renderInvocations": 0,
    "imageGenInvocations": 0,
    "normalizerInvocations": 0,
    "contactSheetInvocations": 0,
    "pixelFiles": 0,
    "sourcePackets": 0,
    "productionReceipts": 0,
}


class ConsumerError(ValueError):
    """Stable fail-closed schedule-consumer error."""


def _reject_duplicate_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    value: dict[str, Any] = {}
    for key, item in pairs:
        if key in value:
            raise ConsumerError(f"DUPLICATE_JSON_KEY:{key}")
        value[key] = item
    return value


def _reject_nonfinite(value: str) -> None:
    raise ConsumerError(f"NONFINITE_JSON_VALUE:{value}")


def decode_json(data: bytes, label: str) -> dict[str, Any]:
    try:
        value = json.loads(
            data.decode("utf-8"),
            object_pairs_hook=_reject_duplicate_pairs,
            parse_constant=_reject_nonfinite,
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ConsumerError(f"INVALID_JSON:{label}") from error
    if not isinstance(value, dict):
        raise ConsumerError(f"EXPECTED_JSON_OBJECT:{label}")
    return value


def canonical_bytes(value: dict[str, Any]) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


def digest_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def safe_repository_file(
    root: Path,
    relative: Any,
    *,
    expected: str | None = None,
) -> Path:
    if expected is not None and relative != expected:
        raise ConsumerError(
            f"LEXICAL_IDENTITY_MISMATCH:{relative!r}!={expected!r}"
        )
    if (
        not isinstance(relative, str)
        or not relative
        or Path(relative).is_absolute()
        or "\\" in relative
    ):
        raise ConsumerError(f"INVALID_REPOSITORY_PATH:{relative!r}")
    parts = relative.split("/")
    if any(not part or part in {".", ".."} for part in parts):
        raise ConsumerError(f"PATH_TRAVERSAL:{relative}")
    repository = root.resolve()
    candidate = repository.joinpath(*parts)
    current = repository
    for part in parts:
        current = current / part
        if current.is_symlink():
            raise ConsumerError(
                f"SYMLINK_COMPONENT:{current.relative_to(repository)}"
            )
    if not candidate.is_file():
        raise ConsumerError(f"MISSING_REGULAR_FILE:{relative}")
    return candidate


def binding_errors(
    root: Path,
    binding: Any,
    label: str,
    *,
    expected_path: str,
    expected_sha256: str,
) -> list[str]:
    if not isinstance(binding, dict) or set(binding) != {"path", "sha256"}:
        return [f"{label}:shape"]
    errors: list[str] = []
    if binding.get("path") != expected_path:
        errors.append(f"{label}:path")
    if binding.get("sha256") != expected_sha256:
        errors.append(f"{label}:sha256-contract")
    try:
        path = safe_repository_file(
            root,
            binding.get("path"),
            expected=expected_path,
        )
    except ConsumerError as error:
        return sorted(set(errors + [f"{label}:unsafe:{error}"]))
    if digest_bytes(path.read_bytes()) != expected_sha256:
        errors.append(f"{label}:sha256-working-tree")
    return sorted(set(errors))


def expected_process_roots(process_id: str) -> dict[str, str]:
    if process_id not in PROCESS_IDS:
        raise ConsumerError(f"INVALID_PROCESS:{process_id}")
    base = (
        "docs/production/evidence/PLAY-081/"
        f"industrial-l04-west-source-v01/process-{process_id}"
    )
    return {
        "rawRoot": f"{base}/raw",
        "semanticRoot": f"{base}/semantic",
        "evidenceRoot": f"{base}/evidence",
    }


def contract_errors(root: Path, contract: dict[str, Any]) -> list[str]:
    required = {
        "schema",
        "schemaVersion",
        "taskId",
        "direction",
        "branch",
        "stage",
        "publishedBase",
        "claim",
        "adapter",
        "adapterAuthority",
        "scheduleSchema",
        "semanticValidator",
        "familyContract",
        "runnerContract",
        "orchestrator",
        "runnerEntrypoint",
        "orchestrationContract",
        "executionClosureSchema",
        "executionClosureValidator",
        "executionClosureAuthority",
        "exclusiveRoots",
        "target",
        "releaseInputs",
        "childPolicy",
        "readinessEvidence",
        "sourceReady",
        "productionSelected",
    }
    if set(contract) != required:
        return ["contract:shape"]
    errors: list[str] = []
    exact_scalars = {
        "schema": "citysim.play-081.west-schedule-consumer.v1",
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "branch": "codex/citysim-world-art-west",
        "stage": "execution_closure_validation_only",
        "publishedBase": "d4f18ea3b1ccfd522f3b5e877bc7cb742fd9be09",
        "sourceReady": False,
        "productionSelected": False,
    }
    for name, expected in exact_scalars.items():
        if contract.get(name) != expected:
            errors.append(f"contract:{name}")

    expected_bindings = {
        "adapter": (
            f"{CONSUMER_ROOT}/consume_west_parallel_schedule_v1.py",
            "SELF_SHA256_FROM_CONTRACT",
        ),
        "claim": (
            "docs/production/claims/PLAY-081.world-art-west.md",
            "52f90aafd67d7bb8083b84e3704ea8eb14c577db7bf9f20145016f36bc6c14aa",
        ),
        "adapterAuthority": (
            "docs/production/evidence/INTEGRATION/"
            "INDUSTRIAL-L04-DIRECTION-SCHEDULE-ADAPTER-AUTHORITY.md",
            "3638f960a9394f9c4c0c09e3aa75ba842ec4d093eada04762eb51f0b1c57dd34",
        ),
        "scheduleSchema": (
            "docs/production/evidence/INTEGRATION/"
            "industrial-l04-parallel-execution-schedule-schema-v1.json",
            "6eba2291f9cb548a8ddd08961bdffe3a18c9546b293a08f094711b38aa0840c6",
        ),
        "semanticValidator": (
            ".agents/skills/operate-citysim-integration/scripts/"
            "validate_industrial_l04_parallel_execution_schedule_v1.py",
            "086ff2f2cb7d0c030d0039b48b3b66f7e6c314dd97a705b8f0a8a41fda0bbb04",
        ),
        "familyContract": (
            "docs/production/decisions/CONTRACT-010-directional-building-art.md",
            "0ee2d68a9dba4694d92a864bfeb5a91970c88fe87d893e1898de7b26d38609af",
        ),
        "runnerContract": (
            f"{SOURCE_ROOT}/RUNNER-CONTRACT.json",
            "ac87bd1013daaa8e21a6204bdd09969489a4e237698b3e95c135949968fe6be1",
        ),
        "orchestrator": (
            f"{SOURCE_ROOT}/west_execution_orchestration_v2.py",
            "SELF_SHA256_FROM_CONTRACT",
        ),
        "runnerEntrypoint": (
            f"{SOURCE_ROOT}/run_west_source.py",
            "SELF_SHA256_FROM_CONTRACT",
        ),
        "orchestrationContract": (
            f"{SOURCE_ROOT}/WEST-EXECUTION-ORCHESTRATION-V2.json",
            "SELF_SHA256_FROM_CONTRACT",
        ),
        "executionClosureSchema": (
            "docs/production/evidence/INTEGRATION/"
            "industrial-l04-direction-execution-authority-schema-v1.json",
            "2796e224780c259b29d68b50cb12cdbbe45452535da681bba3522af920459491",
        ),
        "executionClosureValidator": (
            ".agents/skills/operate-citysim-integration/scripts/"
            "validate_industrial_l04_direction_execution_authority_v1.py",
            "b212d2776d34b3334910c6b0b02ffba244919f4a83d5c0019c30bca87648d8ae",
        ),
        "executionClosureAuthority": (
            "docs/production/evidence/INTEGRATION/"
            "INDUSTRIAL-L04-DIRECTION-EXECUTION-CLOSURE-V1-AUTHORITY.md",
            "0125539f015ab8069c11093e755ac6e43d7b37994c86515fc06894e401b7eb54",
        ),
    }
    for name, (path, sha256) in expected_bindings.items():
        value = contract.get(name)
        if name in {
            "adapter",
            "orchestrator",
            "runnerEntrypoint",
            "orchestrationContract",
        }:
            sha256 = (
                value.get("sha256")
                if isinstance(value, dict)
                else ""
            )
            if not isinstance(sha256, str) or HEX_64.fullmatch(sha256) is None:
                errors.append("adapter:sha256-contract")
                continue
        if name == "claim":
            if not isinstance(value, dict):
                errors.append("claim:shape")
                continue
            if value.get("revision") != 6:
                errors.append("claim:revision")
            value = {
                "path": value.get("path"),
                "sha256": value.get("sha256"),
            }
        errors.extend(
            binding_errors(
                root,
                value,
                name,
                expected_path=path,
                expected_sha256=sha256,
            )
        )

    claim_path = root / expected_bindings["claim"][0]
    if claim_path.is_file() and b"**Claim revision:** 6" not in claim_path.read_bytes():
        errors.append("claim:revision-content")

    expected_roots = [
        SOURCE_ROOT,
        "docs/production/evidence/PLAY-081/industrial-l04-west-source-v01",
    ]
    if contract.get("exclusiveRoots") != expected_roots:
        errors.append("contract:exclusive-roots")

    target = contract.get("target")
    if target != {
        "phase": "postlock_abc",
        "processes": ["A", "B", "C"],
        "queueTokens": ["west:A", "west:B", "west:C"],
    }:
        errors.append("contract:target")

    release = contract.get("releaseInputs")
    expected_release = {
        "schedule": {
            "state": "not_published",
            "path": None,
            "commit": None,
            "sha256": None,
        },
        "appearanceLock": {
            "state": "not_published",
            "path": None,
            "sha256": None,
        },
        "sourceProductionProfile": {
            "state": "not_published",
            "path": None,
            "sha256": None,
        },
        "processGrants": {
            process: {
                "state": "not_published",
                "grantId": None,
            }
            for process in PROCESS_IDS
        },
    }
    if release != expected_release:
        errors.append("contract:release-inputs")

    if contract.get("childPolicy") != {
        "adapterStartsChildren": False,
        "adapterInvokesHighLevelOrchestratorForValidationOnly": True,
        "directLowLevelInvocationAllowed": False,
        "maximumChildStartsWhileBlocked": 0,
    }:
        errors.append("contract:child-policy")
    evidence = contract.get("readinessEvidence")
    if evidence != (
        "docs/production/evidence/PLAY-081/"
        "industrial-l04-west-source-v01/schedule-consumer-v01/"
        "EXECUTION-CLOSURE-V1.json"
    ):
        errors.append("contract:readiness-evidence")
    return sorted(set(errors))


def release_blockers(contract: dict[str, Any]) -> list[str]:
    release = contract.get("releaseInputs", {})
    blockers: list[str] = []
    for name in ("schedule", "appearanceLock", "sourceProductionProfile"):
        value = release.get(name)
        if not isinstance(value, dict) or value.get("state") != "bound_integration":
            blockers.append(f"release:{name}:not-published")
    grants = release.get("processGrants", {})
    for process in PROCESS_IDS:
        value = grants.get(process) if isinstance(grants, dict) else None
        if not isinstance(value, dict) or value.get("state") != "granted":
            blockers.append(f"release:west-{process}:not-granted")
    return blockers


def _binding_matches(
    actual: Any,
    expected: Any,
    label: str,
    errors: list[str],
) -> None:
    if not isinstance(actual, dict) or set(actual) != {"path", "sha256"}:
        errors.append(f"schedule:{label}:shape")
        return
    if actual != expected:
        errors.append(f"schedule:{label}:binding")


def direction_schedule_errors(
    schedule: dict[str, Any],
    contract: dict[str, Any],
) -> list[str]:
    """Validate West-local semantics after the shared validator passes."""
    errors: list[str] = []
    if schedule.get("phase") != contract.get("target", {}).get("phase"):
        errors.append("schedule:phase")
    if schedule.get("integrationAuthorityCommit") != contract.get("publishedBase"):
        errors.append("schedule:integration-authority")
    _binding_matches(
        schedule.get("familyContract"),
        contract.get("familyContract"),
        "family-contract",
        errors,
    )

    release = contract.get("releaseInputs", {})
    for schedule_name, release_name, label in (
        ("appearanceLock", "appearanceLock", "appearance-lock"),
        (
            "sourceProductionProfile",
            "sourceProductionProfile",
            "source-production-profile",
        ),
    ):
        expected = release.get(release_name)
        actual = schedule.get(schedule_name)
        if not isinstance(expected, dict) or expected.get("state") != "bound_integration":
            errors.append(f"release:{label}:not-published")
            continue
        binding = {
            "path": expected.get("path"),
            "sha256": expected.get("sha256"),
        }
        _binding_matches(actual, binding, label, errors)
        if (
            not isinstance(actual, dict)
            or not isinstance(actual.get("path"), str)
            or not actual["path"].startswith(INTEGRATION_PREFIX)
        ):
            errors.append(f"schedule:{label}:path")

    envelope = schedule.get("computeEnvelope")
    if not isinstance(envelope, dict):
        errors.append("schedule:compute-envelope")
        return sorted(set(errors))
    slots = envelope.get("slotIds")
    queue = envelope.get("queueOrder")
    if (
        not isinstance(slots, list)
        or len(slots) < 3
        or len(set(slots)) != len(slots)
    ):
        errors.append("schedule:slots")
        slots = []
    expected_tokens = contract.get("target", {}).get("queueTokens")
    if not isinstance(queue, list) or any(
        token not in queue for token in expected_tokens
    ):
        errors.append("schedule:queue")
    elif [token for token in queue if token in expected_tokens] != expected_tokens:
        errors.append("schedule:west-queue-order")

    grants = schedule.get("directionGrants")
    if not isinstance(grants, list):
        return sorted(set(errors + ["schedule:direction-grants"]))
    west = [
        value
        for value in grants
        if isinstance(value, dict) and value.get("direction") == "west"
    ]
    if len(west) != 1:
        return sorted(set(errors + ["schedule:west-grant-count"]))
    grant = west[0]
    exact = {
        "claim": "PLAY-081",
        "branch": "codex/citysim-world-art-west",
        "claimSha256": contract.get("claim", {}).get("sha256"),
        "baseCommit": contract.get("publishedBase"),
        "orchestrator": contract.get("adapter"),
        "exclusiveRoots": contract.get("exclusiveRoots"),
    }
    for name, expected in exact.items():
        if grant.get(name) != expected:
            errors.append(f"schedule:west-{name}")

    processes = grant.get("processes")
    if not isinstance(processes, list):
        return sorted(set(errors + ["schedule:west-processes"]))
    by_process = {
        value.get("process"): value
        for value in processes
        if isinstance(value, dict)
    }
    if set(by_process) != set(PROCESS_IDS):
        errors.append("schedule:west-process-set")
        return sorted(set(errors))
    release_grants = release.get("processGrants", {})
    for process_id in PROCESS_IDS:
        process = by_process[process_id]
        expected_release = (
            release_grants.get(process_id)
            if isinstance(release_grants, dict)
            else None
        )
        if (
            not isinstance(expected_release, dict)
            or expected_release.get("state") != "granted"
        ):
            errors.append(f"release:west-{process_id}:not-granted")
        elif process.get("grantId") != expected_release.get("grantId"):
            errors.append(f"schedule:west-{process_id}:grant-id")
        if process.get("state") != "granted":
            errors.append(f"schedule:west-{process_id}:state")
        if process.get("slotId") not in slots:
            errors.append(f"schedule:west-{process_id}:slot")
        if process.get("maximumChildStarts") != 1:
            errors.append(f"schedule:west-{process_id}:child-limit")
        if process.get("orchestratorOnly") is not True:
            errors.append(f"schedule:west-{process_id}:orchestrator-only")
        if process.get("directLowLevelInvocationAllowed") is not False:
            errors.append(f"schedule:west-{process_id}:direct-low-level")
    return sorted(set(errors))


def load_shared_validator(root: Path, contract: dict[str, Any]) -> Any:
    binding = contract["semanticValidator"]
    path = safe_repository_file(
        root,
        binding["path"],
        expected=binding["path"],
    )
    if digest_bytes(path.read_bytes()) != binding["sha256"]:
        raise ConsumerError("SEMANTIC_VALIDATOR_SHA256_MISMATCH")
    spec = importlib.util.spec_from_file_location(
        "industrial_l04_schedule_validator_v1",
        path,
    )
    if spec is None or spec.loader is None:
        raise ConsumerError("SEMANTIC_VALIDATOR_IMPORT_FAILED")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def describe(root: Path, contract: dict[str, Any]) -> dict[str, Any]:
    errors = contract_errors(root, contract)
    blockers = release_blockers(contract)
    return {
        "schema": "citysim.play-081.west-zero-child-readiness.v1",
        "taskId": "PLAY-081",
        "direction": "west",
        "branch": "codex/citysim-world-art-west",
        "stage": "execution_closure_validation_only",
        "publishedBase": contract.get("publishedBase"),
        "claimRevision": contract.get("claim", {}).get("revision"),
        "claimSha256": contract.get("claim", {}).get("sha256"),
        "targetPhase": contract.get("target", {}).get("phase"),
        "targetProcesses": contract.get("target", {}).get("processes"),
        "adapterReady": not errors,
        "launchReady": False,
        "sourceReady": False,
        "productionSelected": False,
        "staticErrors": errors,
        "blockers": blockers,
        "bindings": {
            name: contract.get(name)
            for name in (
                "adapterAuthority",
                "adapter",
                "scheduleSchema",
                "semanticValidator",
                "runnerContract",
                "orchestrator",
                "runnerEntrypoint",
                "orchestrationContract",
                "executionClosureSchema",
                "executionClosureValidator",
                "executionClosureAuthority",
            )
        },
        "exclusiveRoots": contract.get("exclusiveRoots"),
        "childPolicy": contract.get("childPolicy"),
        "activity": dict(ZERO_ACTIVITY),
    }


def validate_published_schedule(
    root: Path,
    contract: dict[str, Any],
    schedule_path: str | None,
    schedule_sha256: str | None,
) -> dict[str, Any]:
    errors = contract_errors(root, contract)
    blockers = release_blockers(contract)
    if errors or blockers:
        return {
            "result": "BLOCKED",
            "reasonCodes": sorted(set(errors + blockers)),
            "scheduleRead": False,
            "semanticValidatorInvoked": False,
            "orchestratorInvoked": False,
            "activity": dict(ZERO_ACTIVITY),
        }

    release = contract["releaseInputs"]["schedule"]
    expected_path = release["path"]
    expected_sha = release["sha256"]
    if (
        schedule_path != expected_path
        or schedule_sha256 != expected_sha
        or release.get("commit") != contract["publishedBase"]
        or not isinstance(expected_sha, str)
        or HEX_64.fullmatch(expected_sha) is None
        or not isinstance(release.get("commit"), str)
        or HEX_40.fullmatch(release["commit"]) is None
    ):
        return {
            "result": "BLOCKED",
            "reasonCodes": ["schedule:release-binding"],
            "scheduleRead": False,
            "semanticValidatorInvoked": False,
            "orchestratorInvoked": False,
            "activity": dict(ZERO_ACTIVITY),
        }
    try:
        path = safe_repository_file(root, schedule_path, expected=expected_path)
        data = path.read_bytes()
        if digest_bytes(data) != expected_sha:
            raise ConsumerError("SCHEDULE_SHA256_MISMATCH")
        schedule = decode_json(data, schedule_path)
        validator = load_shared_validator(root, contract)
        validator.validate(root, path)
        errors = direction_schedule_errors(schedule, contract)
    except (ConsumerError, OSError, ValueError) as error:
        errors = [f"schedule:validation:{error}"]
    return {
        "result": "PASS" if not errors else "BLOCKED",
        "reasonCodes": sorted(set(errors)),
        "scheduleRead": True,
        "semanticValidatorInvoked": True,
        "orchestratorInvoked": False,
        "approvedHighLevelOrchestrator": contract["orchestrator"],
        "activity": dict(ZERO_ACTIVITY),
    }


def _load_high_level_orchestrator(
    root: Path,
    contract: dict[str, Any],
) -> Any:
    binding = contract["orchestrator"]
    path = safe_repository_file(
        root,
        binding["path"],
        expected=(
            f"{SOURCE_ROOT}/west_execution_orchestration_v2.py"
        ),
    )
    if digest_bytes(path.read_bytes()) != binding["sha256"]:
        raise ConsumerError("HIGH_LEVEL_ORCHESTRATOR_SHA256_MISMATCH")
    spec = importlib.util.spec_from_file_location(
        "play081_west_execution_closure_orchestrator",
        path,
    )
    if spec is None or spec.loader is None:
        raise ConsumerError("HIGH_LEVEL_ORCHESTRATOR_IMPORT_FAILED")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def validate_execution_closure(
    root: Path,
    contract: dict[str, Any],
    *,
    authority_path: str | None,
    trusted_head: str | None,
    worker_head: str | None,
    authority_publication_commit: str | None,
) -> dict[str, Any]:
    """Route one validation-only authority through the high-level boundary."""
    errors = contract_errors(root, contract)
    arguments = {
        "authority": authority_path,
        "trustedHead": trusted_head,
        "workerHead": worker_head,
        "authorityPublicationCommit": authority_publication_commit,
    }
    for label, value in arguments.items():
        if not isinstance(value, str) or not value:
            errors.append(f"execution-closure:{label}:missing")
    if errors:
        return {
            "schema": "citysim.play-081.west-execution-closure-consumer.v1",
            "taskId": "PLAY-081",
            "direction": "west",
            "result": "BLOCKED",
            "reasonCodes": sorted(set(errors)),
            "consumerInvoked": True,
            "highLevelOrchestratorInvoked": False,
            "runnerValidationBoundaryReached": False,
            "activity": dict(ZERO_ACTIVITY),
        }
    try:
        orchestrator = _load_high_level_orchestrator(root, contract)
        execution_contract_path = safe_repository_file(
            root,
            contract["orchestrationContract"]["path"],
            expected=contract["orchestrationContract"]["path"],
        )
        execution_contract = decode_json(
            execution_contract_path.read_bytes(),
            contract["orchestrationContract"]["path"],
        )
        result = orchestrator.validate_execution_closure(
            root,
            execution_contract,
            authority_path=authority_path,
            trusted_head=trusted_head,
            worker_head=worker_head,
            authority_publication_commit=authority_publication_commit,
        )
    except (ConsumerError, OSError, ValueError) as error:
        return {
            "schema": "citysim.play-081.west-execution-closure-consumer.v1",
            "taskId": "PLAY-081",
            "direction": "west",
            "result": "BLOCKED",
            "reasonCodes": [f"execution-closure:orchestrator:{error}"],
            "consumerInvoked": True,
            "highLevelOrchestratorInvoked": False,
            "runnerValidationBoundaryReached": False,
            "activity": dict(ZERO_ACTIVITY),
        }
    packet = dict(result)
    packet["consumer"] = contract["adapter"]
    packet["consumerInvoked"] = True
    packet["highLevelOrchestratorInvoked"] = True
    return packet


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", default=DEFAULT_CONTRACT)
    parser.add_argument(
        "--mode",
        required=True,
        choices=("describe", "validate", "validate-closure"),
    )
    parser.add_argument("--schedule")
    parser.add_argument("--schedule-sha256")
    parser.add_argument("--authority")
    parser.add_argument("--trusted-head")
    parser.add_argument("--worker-head")
    parser.add_argument("--authority-publication-commit")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = Path(args.repository_root).resolve()
    contract_path = safe_repository_file(
        root,
        args.contract,
        expected=DEFAULT_CONTRACT,
    )
    contract = decode_json(contract_path.read_bytes(), args.contract)
    if args.mode == "describe":
        result = describe(root, contract)
        print(canonical_bytes(result).decode("utf-8"), end="")
        return 0 if result["adapterReady"] else 1
    if args.mode == "validate-closure":
        result = validate_execution_closure(
            root,
            contract,
            authority_path=args.authority,
            trusted_head=args.trusted_head,
            worker_head=args.worker_head,
            authority_publication_commit=args.authority_publication_commit,
        )
        print(canonical_bytes(result).decode("utf-8"), end="")
        return 0 if result["result"] == "PASS" else 3
    result = validate_published_schedule(
        root,
        contract,
        args.schedule,
        args.schedule_sha256,
    )
    print(canonical_bytes(result).decode("utf-8"), end="")
    return 0 if result["result"] == "PASS" else 3


if __name__ == "__main__":
    raise SystemExit(main())
