#!/usr/bin/env python3
"""High-level one-child launcher for a future North v12 Process A grant."""

from __future__ import annotations

import argparse
import base64
import hashlib
import hmac
import importlib.util
import json
import os
import platform
import secrets
import signal
import stat
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any, Callable


SOURCE_ROOT = Path(
    "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
    "industrial-l04-north-art-v12/process-a-execution-v01"
)
CONTRACT_RELATIVE = SOURCE_ROOT / "EXECUTION-CONTRACT.json"
LAUNCHER_RELATIVE = SOURCE_ROOT / "launch_north_process_a.py"
INTEGRATION_ROOT = Path("docs/production/evidence/INTEGRATION")
HELPER_PROCESS_AUDIT: list[dict[str, Any]] = []
EXPECTED_CURRENT_AUTHORITY_REPLAY = {
    "refreshAuthority": {
        "path": (
            "docs/production/evidence/INTEGRATION/"
            "INDUSTRIAL-L04-CURRENT-MASTER-AUTHORITY-REFRESH-2026-07-30.md"
        ),
        "sha256": "75ec7518371b5a822f2650a8b8427289112debbe806e3e82b5809fd43865a46c",
    },
    "sourceStageSchema": {
        "path": (
            "docs/production/evidence/INTEGRATION/"
            "industrial-l04-source-stage-handoff-schema-v2.json"
        ),
        "sha256": "85f6a2824c273a1e63354df79a97e5a59c2909a68771613b325664d649ac53ec",
    },
    "nonAliasInput": {
        "path": (
            "docs/production/evidence/INTEGRATION/"
            "industrial-l04-accepted-master-non-alias-input-v1.json"
        ),
        "sha256": "d1d75fdc30d9a2f21d49b59fd13dbc6fe7d81669f76f801d1087b35a7fb70044",
    },
    "nonAliasLoader": {
        "path": (
            "Native/CitySimNative/WorldArt/Shared/"
            "accepted_master_non_alias_v1.py"
        ),
        "sha256": "83716838d310b5a5a3be51091b255d2a5eabb1b2f28d9af72a89a885779f3a7d",
    },
    "acceptedMasterCount": 44,
    "forbiddenSetSHA256": "265c564785a5fa4ce14fbd04898ef04aaed883e2ca56f6a0660a9937464926ea",
}


class LaunchError(ValueError):
    """A fail-closed prelaunch or execution-boundary rejection."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise LaunchError(message)


def canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, indent=2, sort_keys=True, separators=(",", ": "))
        + "\n"
    ).encode("utf-8")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"JSON object required: {path.name}")
    return value


def resolve_regular(repository_root: Path, relative: str, label: str) -> Path:
    require(relative and not relative.startswith("/"), f"{label} path must be relative")
    lexical = repository_root / relative
    current = repository_root
    for component in Path(relative).parts:
        current = current / component
        require(not current.is_symlink(), f"{label} path contains a symlink")
    resolved = lexical.resolve(strict=True)
    require(resolved.is_relative_to(repository_root), f"{label} escapes repository")
    require(resolved.is_file(), f"{label} must be a regular file")
    return resolved


def verify_binding(
    repository_root: Path,
    binding: Any,
    label: str,
    *,
    expected_path: str | None = None,
    expected_sha256: str | None = None,
) -> Path:
    require(isinstance(binding, dict), f"{label} binding must be an object")
    require(set(binding) == {"path", "sha256"}, f"{label} binding fields drift")
    if expected_path is not None:
        require(binding["path"] == expected_path, f"{label} path drift")
    if expected_sha256 is not None:
        require(binding["sha256"] == expected_sha256, f"{label} hash drift")
    path = resolve_regular(repository_root, binding["path"], label)
    require(sha256(path) == binding["sha256"], f"{label} bytes drift")
    return path


def git_check(repository_root: Path, arguments: list[str]) -> str:
    require(
        arguments
        and arguments[0]
        in {"branch", "cat-file", "merge-base", "rev-parse", "status"},
        "unapproved Git prelaunch operation",
    )
    result = subprocess.run(
        ["git", *arguments],
        cwd=repository_root,
        capture_output=True,
        text=True,
        check=False,
    )
    HELPER_PROCESS_AUDIT.append(
        {"class": "git-read-only", "argv": ["git", *arguments]}
    )
    require(result.returncode == 0, f"Git binding failed: {' '.join(arguments)}")
    return result.stdout.strip()


def git_bytes(repository_root: Path, arguments: list[str]) -> bytes:
    require(
        arguments and arguments[0] == "show",
        "unapproved binary Git prelaunch operation",
    )
    result = subprocess.run(
        ["git", *arguments],
        cwd=repository_root,
        capture_output=True,
        check=False,
    )
    HELPER_PROCESS_AUDIT.append(
        {"class": "git-read-only", "argv": ["git", *arguments]}
    )
    require(result.returncode == 0, f"Git binding failed: {' '.join(arguments)}")
    return result.stdout


def require_commit(repository_root: Path, commit: str, label: str) -> None:
    require(
        len(commit) == 40
        and all(character in "0123456789abcdef" for character in commit),
        f"{label} must be a full commit",
    )
    git_check(repository_root, ["cat-file", "-e", f"{commit}^{{commit}}"])


def require_ancestor_of(
    repository_root: Path,
    commit: str,
    descendant: str,
    label: str,
) -> None:
    require_commit(repository_root, commit, label)
    require_commit(repository_root, descendant, f"{label}Descendant")
    git_check(repository_root, ["merge-base", "--is-ancestor", commit, descendant])


def require_ancestor(repository_root: Path, commit: str, label: str) -> None:
    require_commit(repository_root, commit, label)
    git_check(repository_root, ["merge-base", "--is-ancestor", commit, "HEAD"])


def verify_trusted_integration_head(
    repository_root: Path,
    contract: dict[str, Any],
    trusted_integration_head: str,
) -> dict[str, str]:
    require_commit(repository_root, trusted_integration_head, "trustedIntegrationHead")
    trust = contract["integrationTrust"]
    remote_ref = trust["remoteRef"]
    actual = git_check(repository_root, ["rev-parse", "--verify", remote_ref])
    require(
        actual == trusted_integration_head,
        "trusted Integration head does not match fetched origin/master",
    )
    require_ancestor_of(
        repository_root,
        trust["minimumAuthorityCommit"],
        trusted_integration_head,
        "minimumIntegrationAuthority",
    )
    git_check(
        repository_root,
        ["merge-base", "--is-ancestor", trusted_integration_head, "HEAD"],
    )
    return {"remoteRef": remote_ref, "commit": trusted_integration_head}


def normalize_repository_file(
    repository_root: Path,
    supplied: Path,
    label: str,
) -> Path:
    lexical = supplied if supplied.is_absolute() else repository_root / supplied
    lexical = lexical.absolute()
    require(lexical.is_relative_to(repository_root), f"{label} escapes repository")
    relative = lexical.relative_to(repository_root)
    current = repository_root
    for component in relative.parts:
        current = current / component
        require(not current.is_symlink(), f"{label} path contains a symlink")
    resolved = lexical.resolve(strict=True)
    require(resolved.is_relative_to(repository_root), f"{label} escapes repository")
    require(resolved.is_file(), f"{label} must be a regular file")
    return resolved


def verify_integration_publication(
    repository_root: Path,
    path: Path,
    publication_commit: str,
    trusted_integration_head: str,
    label: str,
) -> dict[str, str]:
    resolved = normalize_repository_file(repository_root, path, label)
    integration_root = (repository_root / INTEGRATION_ROOT).resolve(strict=True)
    require(resolved.is_relative_to(integration_root), f"{label} is outside Integration root")
    require_ancestor_of(
        repository_root,
        publication_commit,
        trusted_integration_head,
        f"{label}PublicationCommit",
    )
    relative = resolved.relative_to(repository_root)
    status = git_check(
        repository_root,
        ["status", "--porcelain=v1", "--", str(relative)],
    )
    require(not status, f"{label} worktree bytes are dirty")
    published = git_bytes(
        repository_root,
        ["show", f"{publication_commit}:{relative}"],
    )
    require(published == resolved.read_bytes(), f"{label} bytes are stale")
    return {"path": str(relative), "sha256": sha256(resolved)}


def read_authorization_secret(descriptor: int) -> bytes:
    require(descriptor >= 3, "Integration authorization secret fd missing")
    try:
        descriptor_stat = os.fstat(descriptor)
    except OSError as error:
        raise LaunchError("Integration authorization secret fd missing") from error
    require(
        stat.S_ISFIFO(descriptor_stat.st_mode),
        "Integration authorization secret must arrive through an anonymous pipe",
    )
    with os.fdopen(descriptor, "rb", closefd=True) as handle:
        secret = handle.read(257)
    require(32 <= len(secret) <= 256, "Integration authorization secret size invalid")
    return secret


def validate_execution_closure(
    repository_root: Path,
    contract: dict[str, Any],
    authority_path: Path,
    authority_publication_commit: str,
    schedule_path: Path,
    schedule_publication_commit: str,
    output_root: Path,
    authorization_secret: bytes,
    trusted_integration_head: str,
) -> dict[str, Any]:
    integration_trust = verify_trusted_integration_head(
        repository_root,
        contract,
        trusted_integration_head,
    )
    normalized_schedule = normalize_repository_file(
        repository_root,
        schedule_path,
        "schedule",
    )
    normalized_authority = normalize_repository_file(
        repository_root,
        authority_path,
        "executionClosureAuthority",
    )
    closure = contract["executionClosure"]
    closure_validator_path = verify_binding(
        repository_root,
        closure["validator"],
        "executionClosure.validator",
    )
    validator = load_module(
        closure_validator_path,
        "play027_integration_execution_closure_validator",
    )
    require(
        callable(getattr(validator, "validate", None)),
        "shared execution-closure validator entrypoint missing",
    )
    worker_head = git_check(repository_root, ["rev-parse", "--verify", "HEAD"])
    validation = validator.validate(
        repository_root,
        normalized_authority,
        trusted_head=trusted_integration_head,
        worker_head=worker_head,
        authority_publication_commit=authority_publication_commit,
    )
    require(validation["result"] == "PASS", "shared execution closure did not pass")
    authority = load_json(normalized_authority)
    require(
        authority["schedule"]
        == {
            "path": str(normalized_schedule.relative_to(repository_root)),
            "sha256": sha256(normalized_schedule),
            "publicationCommit": schedule_publication_commit,
            "phase": contract["phase"],
        },
        "shared execution closure schedule drift",
    )
    expected_artifacts = {
        "executionContract": {
            "path": str(CONTRACT_RELATIVE),
            "sha256": sha256(repository_root / CONTRACT_RELATIVE),
        },
        "directionScheduleAdapter": contract["scheduleAdapter"]["consumer"],
        "highLevelOrchestrator": contract["launcher"],
        "runnerContract": contract["runnerContract"],
        "runnerEntrypoint": contract["childEntrypoint"],
        "scene": contract["frozenNorthV12Inputs"]["scene"],
        "materials": contract["frozenNorthV12Inputs"]["materials"],
        "toolchain": contract["frozenNorthV12Inputs"]["loweringContract"],
    }
    require(
        authority["artifacts"] == expected_artifacts,
        "shared execution closure artifact binding drift",
    )
    grant = authority["grant"]
    require(
        grant
        == {
            "grantId": "north:A",
            "process": "A",
            "queueId": "north:A",
            "slotId": "dcc-1",
            "maximumChildStarts": 1,
            "exactlyOneInvocation": True,
            "orchestratorOnly": True,
            "directLowLevelInvocationAllowed": False,
        },
        "shared execution closure grant drift",
    )
    roots = authority["exclusiveRoots"]
    require(
        roots == contract["executionRoots"],
        "shared execution closure exclusive-root drift",
    )
    require(
        output_root.absolute() == (repository_root / roots["output"]).absolute(),
        "shared execution closure output root drift",
    )
    envelope = authority["executionEnvelope"]
    require(
        envelope["timeoutSeconds"] == contract["processEnvelope"]["timeoutSeconds"],
        "shared execution closure timeout drift",
    )
    require(
        envelope["maximumRSSBytes"]
        == contract["processEnvelope"]["maximumProcessGroupRSSMiB"] * 1024 * 1024,
        "shared execution closure RSS drift",
    )
    require(
        authority["authentication"]["secretSha256"]
        == sha256_bytes(authorization_secret),
        "shared execution closure secret mismatch",
    )
    require(
        git_check(repository_root, ["status", "--porcelain=v1"]) == "",
        "execution requires a clean worktree",
    )
    return {
        "grantId": grant["grantId"],
        "slotId": grant["slotId"],
        "attemptId": grant["grantId"],
        "attemptRecordPath": str(Path(roots["attempt"]) / "north-A.json"),
        "terminalRoot": roots["terminal"],
        "authorizationSecretSHA256": authority["authentication"]["secretSha256"],
        "schedule": authority["schedule"],
        "exclusiveRoots": roots,
        "executionEnvelope": envelope,
        "authentication": authority["authentication"],
        "closureValidation": validation,
        "path": str(normalized_authority.relative_to(repository_root)),
        "sha256": sha256(normalized_authority),
        "publicationCommit": authority_publication_commit,
        "trustedIntegrationHead": integration_trust,
    }


def load_module(path: Path, name: str) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    require(spec is not None and spec.loader is not None, f"{name} import failed")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def validate_current_authority_replay(
    repository_root: Path,
    value: Any,
) -> dict[str, Any]:
    require(
        value == EXPECTED_CURRENT_AUTHORITY_REPLAY,
        "current authority replay binding drift",
    )
    for label in (
        "refreshAuthority",
        "sourceStageSchema",
        "nonAliasInput",
        "nonAliasLoader",
    ):
        verify_binding(
            repository_root,
            value[label],
            f"currentAuthorityReplay.{label}",
            expected_path=EXPECTED_CURRENT_AUTHORITY_REPLAY[label]["path"],
            expected_sha256=EXPECTED_CURRENT_AUTHORITY_REPLAY[label]["sha256"],
        )
    loader = load_module(
        repository_root / value["nonAliasLoader"]["path"],
        "play027_current_non_alias_loader",
    )
    require(
        callable(getattr(loader, "load_forbidden_decoded_rgba", None)),
        "non-alias loader entrypoint missing",
    )
    require(
        getattr(loader, "INPUT_SHA256", None) == value["nonAliasInput"]["sha256"],
        "non-alias loader input binding drift",
    )
    require(
        getattr(loader, "FORBIDDEN_SET_SHA256", None)
        == value["forbiddenSetSHA256"],
        "non-alias loader forbidden-set binding drift",
    )
    return value


def validate_execution_contract(
    repository_root: Path,
    contract_path: Path,
) -> dict[str, Any]:
    repository_root = repository_root.resolve(strict=True)
    expected_path = (repository_root / CONTRACT_RELATIVE).resolve(strict=True)
    require(contract_path.resolve(strict=True) == expected_path, "exact execution contract required")
    contract = load_json(expected_path)
    expected_fields = {
        "schema",
        "task",
        "batch",
        "direction",
        "process",
        "phase",
        "prelockProcessPolicy",
        "branch",
        "authorityBaseCommit",
        "publicationCommit",
        "integrationTrust",
        "claim",
        "currentAuthorityReplay",
        "prelaunchAuthority",
        "familyContract",
        "scheduleAdapter",
        "executionClosure",
        "runnerContract",
        "frozenNorthV12Inputs",
        "launcher",
        "childEntrypoint",
        "tests",
        "blender",
        "cycles",
        "processEnvelope",
        "processOutputRoot",
        "executionRoots",
        "directionRootMap",
        "futureDirectionHandoff",
        "capabilityChannel",
        "allowedProcessOutputs",
        "prohibitedSurfaces",
        "sourceAuthority",
        "candidateReadyForIndependentReview",
        "productionSelected",
    }
    require(set(contract) == expected_fields, "execution contract fields drift")
    exact = {
        "schema": 1,
        "task": "PLAY-027",
        "batch": "industrial_l04_directional_family",
        "direction": "north",
        "process": "A",
        "phase": "prelock_north_a",
        "branch": "codex/citysim-world-art",
        "authorityBaseCommit": "aaee294718a8176b70a4688b738b517f216dd3a7",
        "publicationCommit": "aaee294718a8176b70a4688b738b517f216dd3a7",
        "processOutputRoot": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
            "industrial-l04-north-art-v12/process-a-execution-v01/"
            "outputs/process-a"
        ),
        "sourceAuthority": False,
        "candidateReadyForIndependentReview": False,
        "productionSelected": False,
    }
    for field, value in exact.items():
        require(contract[field] == value, f"execution contract drift: {field}")
    require(
        contract["prelockProcessPolicy"]
        == {
            "authorizedProcess": "A",
            "maximumScheduledAndGrantedProcesses": 1,
            "processB": "post-lock-only",
            "processC": "post-lock-only",
            "stopAfterProcessA": True,
        },
        "pre-lock Process-A policy drift",
    )
    require(
        contract["integrationTrust"]
        == {
            "remoteRef": "refs/remotes/origin/master",
            "minimumAuthorityCommit": "aaee294718a8176b70a4688b738b517f216dd3a7",
        },
        "Integration trust-root policy drift",
    )
    root_map = contract["directionRootMap"]
    require(
        isinstance(root_map, dict)
        and set(root_map)
        == {
            "sceneRoot",
            "rawRoot",
            "normalizedRoot",
            "processRoot",
            "outputRoot",
            "evidenceRoot",
            "handoffRoot",
        },
        "direction root-map fields drift",
    )
    north_source_prefix = Path(
        "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v12"
    )
    north_evidence_prefix = Path(
        "docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v12"
    )
    for label, value in root_map.items():
        path = Path(value)
        require(not path.is_absolute() and ".." not in path.parts, f"{label} path drift")
        expected_prefix = (
            north_source_prefix
            if label in {"sceneRoot", "processRoot", "rawRoot", "outputRoot"}
            else north_evidence_prefix
        )
        require(
            path == expected_prefix or path.is_relative_to(expected_prefix),
            f"{label} leaves North claim roots",
        )
        require(
            not any(token in path.parts for token in ("east", "south", "west")),
            f"{label} intersects a sibling root",
        )
    require(
        root_map["rawRoot"] == root_map["outputRoot"]
        and root_map["outputRoot"] == contract["processOutputRoot"],
        "Process-A raw/output root binding drift",
    )
    require(
        contract["executionRoots"]
        == {
            "output": contract["processOutputRoot"],
            "evidence": (
                "docs/production/evidence/PLAY-027/industrial-l04/l04/"
                "blender-north-art-v12/process-a-execution-v01/evidence/process-a"
            ),
            "attempt": (
                "docs/production/evidence/PLAY-027/industrial-l04/l04/"
                "blender-north-art-v12/process-a-execution-v01/attempts/north-A"
            ),
            "terminal": (
                "docs/production/evidence/PLAY-027/industrial-l04/l04/"
                "blender-north-art-v12/process-a-execution-v01/terminals/north-A"
            ),
        },
        "execution-closure root binding drift",
    )
    future_handoff = contract["futureDirectionHandoff"]
    require(
        future_handoff["currentState"] == "not_produced"
        and future_handoff["requiredClaimBinding"] == contract["claim"]
        and future_handoff["parallelExecutionReceipt"]["currentSHA256"] is None
        and future_handoff["parallelExecutionReceipt"]["sha256RequiredAtHandoff"] is True,
        "future direction-handoff binding drift",
    )
    require(
        Path(future_handoff["parallelExecutionReceipt"]["path"]).parent
        == Path(root_map["handoffRoot"]),
        "parallel-execution receipt leaves handoff root",
    )
    require(
        future_handoff["rootAssertions"]
        == {
            "allRootsInsideNorthClaimPrefixes": True,
            "siblingRootIntersectionAllowed": False,
            "sharedContractRootIntersectionAllowed": False,
            "futureProcessOutputRootsPairwiseDisjoint": True,
            "rawRootEqualsSingleProcessAOutputRoot": True,
        },
        "direction root disjointness assertions drift",
    )
    expected_bindings = {
        "claim": (
            "docs/production/claims/PLAY-027.world-art.md",
            "53efe6f2f7931fa50cfd20af48892ea4237a4ddc4a7ec645696f0d4f4fb420a0",
        ),
        "prelaunchAuthority": (
            "docs/production/evidence/INTEGRATION/"
            "INDUSTRIAL-L04-NORTH-V12-PROCESS-A-PRELAUNCH-AUTHORITY.md",
            "889fd6f87a0d7eb112fe392d66901e927658a86a6d3aa311e53178d61cb4725e",
        ),
        "familyContract": (
            "docs/production/decisions/CONTRACT-010-directional-building-art.md",
            "0ee2d68a9dba4694d92a864bfeb5a91970c88fe87d893e1898de7b26d38609af",
        ),
    }
    for label, (path, digest) in expected_bindings.items():
        verify_binding(
            repository_root,
            contract[label],
            label,
            expected_path=path,
            expected_sha256=digest,
        )
    validate_current_authority_replay(
        repository_root,
        contract["currentAuthorityReplay"],
    )
    adapter = contract["scheduleAdapter"]
    require(
        isinstance(adapter, dict)
        and set(adapter) == {"contract", "consumer", "acceptedReadiness"},
        "schedule-adapter inventory drift",
    )
    for label, binding in adapter.items():
        verify_binding(repository_root, binding, f"scheduleAdapter.{label}")
    closure = contract["executionClosure"]
    require(
        isinstance(closure, dict)
        and set(closure) == {"authority", "schema", "validator", "validatorTests"},
        "execution-closure inventory drift",
    )
    expected_closure = {
        "authority": (
            "docs/production/evidence/INTEGRATION/"
            "INDUSTRIAL-L04-DIRECTION-EXECUTION-CLOSURE-V1-AUTHORITY.md",
            "0125539f015ab8069c11093e755ac6e43d7b37994c86515fc06894e401b7eb54",
        ),
        "schema": (
            "docs/production/evidence/INTEGRATION/"
            "industrial-l04-direction-execution-authority-schema-v1.json",
            "2796e224780c259b29d68b50cb12cdbbe45452535da681bba3522af920459491",
        ),
        "validator": (
            ".agents/skills/operate-citysim-integration/scripts/"
            "validate_industrial_l04_direction_execution_authority_v1.py",
            "b212d2776d34b3334910c6b0b02ffba244919f4a83d5c0019c30bca87648d8ae",
        ),
        "validatorTests": (
            ".agents/skills/operate-citysim-integration/scripts/"
            "test_validate_industrial_l04_direction_execution_authority_v1.py",
            "0be62c7886a2106c81e7e05d56eb3ec3c0756365e416686489f8ffe8c76b2520",
        ),
    }
    for label, (path, digest) in expected_closure.items():
        verify_binding(
            repository_root,
            closure[label],
            f"executionClosure.{label}",
            expected_path=path,
            expected_sha256=digest,
        )
    verify_binding(repository_root, contract["runnerContract"], "runnerContract")
    frozen = contract["frozenNorthV12Inputs"]
    require(
        isinstance(frozen, dict)
        and set(frozen)
        == {
            "scene",
            "materials",
            "loweringContract",
            "lowerer",
            "importer",
            "acceptedStaticBContract",
        },
        "frozen input inventory drift",
    )
    for label, binding in frozen.items():
        verify_binding(repository_root, binding, f"frozenNorthV12Inputs.{label}")
    verify_binding(
        repository_root,
        contract["launcher"],
        "launcher",
        expected_path=str(LAUNCHER_RELATIVE),
    )
    verify_binding(repository_root, contract["childEntrypoint"], "childEntrypoint")
    verify_binding(repository_root, contract["tests"], "tests")
    blender = contract["blender"]
    require(
        blender
        == {
            "executable": "/Applications/Blender.app/Contents/MacOS/Blender",
            "executableSHA256": "8485107307b16bd0899f3c259261494b0c80e383db239c04e2c9fcd14d305fb4",
            "version": "4.5.12 LTS",
            "buildHash": "84afd5f785f7",
            "factoryStartup": True,
            "autoexecDisabled": True,
            "pythonExitCode": 1,
        },
        "Blender contract drift",
    )
    require(contract["cycles"]["threads"] == 1, "Cycles thread cap drift")
    require(
        contract["allowedProcessOutputs"]
        == [
            "CHILD-GRANT.json",
            "GROUND-PROJECTION.json",
            "INPUT-BINDINGS.json",
            "OBJECT-MANIFEST.json",
            "PROCESS-RECEIPT.json",
            "provenance.json",
            "raw.png",
            "semantic.png",
        ],
        "allowed Process-A output inventory drift",
    )
    require(
        contract["capabilityChannel"]
        == {
            "type": "integration-secret-plus-launcher-session-hmac",
            "oneUse": True,
            "parentPIDBound": True,
            "executionAuthorityBound": True,
            "outputDirectoryFDBound": True,
            "durableAttemptRecordBound": True,
            "secretTransport": "inherited-anonymous-pipe-only",
            "payloadMaximumBytes": 8192,
            "hashAlgorithm": "HMAC-SHA-256",
        },
        "launcher capability channel drift",
    )
    envelope = contract["processEnvelope"]
    require(
        envelope
        == {
            "maximumChildStarts": 1,
            "maximumConcurrentDCCProcesses": 1,
            "timeoutSeconds": 120,
            "maximumProcessGroupRSSMiB": 1024,
            "newProcessGroup": True,
            "killProcessGroupOnViolation": True,
        },
        "process envelope drift",
    )
    require_ancestor(repository_root, contract["authorityBaseCommit"], "authorityBaseCommit")
    require_ancestor(repository_root, contract["publicationCommit"], "publicationCommit")
    require(
        git_check(repository_root, ["branch", "--show-current"]) == contract["branch"],
        "attached branch mismatch",
    )
    return contract


def validate_output_root(
    repository_root: Path,
    contract: dict[str, Any],
    requested: Path,
    *,
    exists: Callable[[Path], bool] = os.path.lexists,
) -> Path:
    expected = (repository_root / contract["processOutputRoot"]).absolute()
    lexical = requested.absolute()
    require(lexical == expected, "exact Process-A output root required")
    require(lexical.is_relative_to(repository_root), "Process-A output escapes repository")
    current = repository_root
    for component in lexical.relative_to(repository_root).parts:
        current = current / component
        require(not current.is_symlink(), "Process-A output path contains a symlink")
    require(not exists(lexical), "Process-A output root already exists")
    return lexical


def validate_grant_plan(
    contract: dict[str, Any],
    grant: dict[str, Any],
    requested_output: Path,
    repository_root: Path,
    *,
    requested_process: str = "A",
    requested_child_starts: int = 1,
    output_exists: Callable[[Path], bool] = os.path.lexists,
) -> dict[str, Any]:
    require(grant.get("grantValidated") is True, "schedule grant is not validated")
    require(grant.get("processStarted") is False, "schedule grant was already consumed")
    require(grant.get("task") == contract["task"], "grant task drift")
    require(grant.get("batch") == contract["batch"], "grant batch drift")
    require(grant.get("phase") == contract["phase"], "grant phase drift")
    require(grant.get("direction") == contract["direction"], "grant direction drift")
    require(grant.get("grantId") == "north:A", "grantId drift")
    require(requested_process == contract["process"], "only North Process A is supported")
    require(grant.get("process") == requested_process, "grant process drift")
    require(grant.get("slotId") == "dcc-1", "grant slot drift")
    require(grant.get("maximumChildStarts") == 1, "grant child limit drift")
    require(requested_child_starts == 1, "exactly one child start required")
    require(grant.get("directLowLevelInvocationAllowed") is False, "low-level bypass enabled")
    require(grant.get("claimSHA256") == contract["claim"]["sha256"], "grant claim drift")
    require(
        grant.get("publishedBaseCommit") == contract["authorityBaseCommit"],
        "grant base drift",
    )
    require(
        grant.get("exclusiveRoots")
        == [
            "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v12",
            "docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v12",
        ],
        "grant root drift",
    )
    require(grant.get("orchestrator") == contract["launcher"], "grant orchestrator drift")
    require(
        grant.get("frozenNorthV12Inputs") == contract["frozenNorthV12Inputs"],
        "grant frozen-input drift",
    )
    require(
        grant.get("currentAuthorityReplay") == contract["currentAuthorityReplay"],
        "grant current-authority replay drift",
    )
    output_root = validate_output_root(
        repository_root,
        contract,
        requested_output,
        exists=output_exists,
    )
    return {
        "grant": grant,
        "outputRoot": str(output_root.relative_to(repository_root)),
        "requestedChildStarts": 1,
        "validated": True,
    }


def build_child_command(
    repository_root: Path,
    contract_path: Path,
    contract: dict[str, Any],
    output_root_fd: int,
    capability_read_fd: int,
) -> list[str]:
    return [
        contract["blender"]["executable"],
        "--background",
        "--factory-startup",
        "--disable-autoexec",
        "--threads",
        "1",
        "--python-exit-code",
        "1",
        "--python",
        str(repository_root / contract["childEntrypoint"]["path"]),
        "--",
        "--repository-root",
        str(repository_root),
        "--contract",
        str(contract_path),
        "--output-root-fd",
        str(output_root_fd),
        "--child-grant-name",
        "CHILD-GRANT.json",
        "--capability-fd",
        str(capability_read_fd),
    ]


def process_group_snapshot(process_group_id: int) -> list[dict[str, int]]:
    HELPER_PROCESS_AUDIT.append(
        {
            "class": "process-observer",
            "argv": ["/bin/ps", "-axo", "pid=,pgid=,rss="],
        }
    )
    result = subprocess.run(
        ["/bin/ps", "-axo", "pid=,pgid=,rss="],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise LaunchError("process-group RSS sampling failed")
    members = []
    for line in result.stdout.splitlines():
        fields = line.split()
        if len(fields) == 3 and int(fields[1]) == process_group_id:
            members.append({"pid": int(fields[0]), "rssKiB": int(fields[2])})
    return sorted(members, key=lambda item: item["pid"])


def terminal_rss_kib(usage: Any) -> int:
    require(sys.platform == "darwin", "Process-A resource model requires Darwin")
    value = getattr(usage, "ru_maxrss", None)
    require(isinstance(value, int) and value > 0, "terminal ru_maxrss is unavailable")
    return (value + 1023) // 1024


def verify_blender_executable(contract: dict[str, Any]) -> Path:
    path = Path(contract["blender"]["executable"])
    require(path.is_absolute(), "Blender executable must be absolute")
    require(not path.is_symlink(), "Blender executable must not be a symlink")
    require(path.is_file(), "Blender executable is missing")
    require(
        sha256(path) == contract["blender"]["executableSHA256"],
        "Blender executable bytes drift",
    )
    return path


def terminate_group(process_group_id: int) -> None:
    try:
        os.killpg(process_group_id, signal.SIGTERM)
    except ProcessLookupError:
        return
    time.sleep(0.2)
    try:
        os.killpg(process_group_id, signal.SIGKILL)
    except ProcessLookupError:
        pass


def enforce_resource_observation(
    process_group_id: int,
    *,
    elapsed_seconds: float,
    sampled_peak_rss_kib: int,
    maximum_seconds: float,
    maximum_rss_kib: int,
    observed_extra_members: set[int],
    terminate: Callable[[int], None] = terminate_group,
) -> str | None:
    reason = None
    if elapsed_seconds > maximum_seconds:
        reason = "timeout"
    elif sampled_peak_rss_kib > maximum_rss_kib:
        reason = "rss-limit"
    elif observed_extra_members:
        reason = "unexpected-process-group-member"
    if reason is not None:
        terminate(process_group_id)
    return reason


def write_exclusive(path: Path, value: Any) -> None:
    descriptor = os.open(
        path,
        os.O_WRONLY
        | os.O_CREAT
        | os.O_EXCL
        | (os.O_NOFOLLOW if hasattr(os, "O_NOFOLLOW") else 0),
        0o644,
    )
    try:
        payload = canonical_bytes(value)
        offset = 0
        while offset < len(payload):
            offset += os.write(descriptor, payload[offset:])
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def open_directory_chain(
    repository_root: Path,
    relative: Path,
    *,
    create_leaf: bool,
) -> int:
    require(not relative.is_absolute() and ".." not in relative.parts, "directory path drift")
    descriptor = os.open(
        repository_root,
        os.O_RDONLY | os.O_DIRECTORY | getattr(os, "O_NOFOLLOW", 0),
    )
    try:
        for index, component in enumerate(relative.parts):
            is_leaf = index == len(relative.parts) - 1
            if is_leaf and create_leaf:
                os.mkdir(component, 0o755, dir_fd=descriptor)
            next_descriptor = os.open(
                component,
                os.O_RDONLY | os.O_DIRECTORY | getattr(os, "O_NOFOLLOW", 0),
                dir_fd=descriptor,
            )
            os.close(descriptor)
            descriptor = next_descriptor
        return descriptor
    except BaseException:
        os.close(descriptor)
        raise


def open_parent_directory(repository_root: Path, relative: Path) -> tuple[int, str]:
    require(relative.name and relative.parent != Path("."), "file path requires a parent")
    return (
        open_directory_chain(repository_root, relative.parent, create_leaf=False),
        relative.name,
    )


def open_or_create_directory_chain(repository_root: Path, relative: Path) -> int:
    """Open a repository-relative directory, securely creating missing members."""
    require(
        not relative.is_absolute() and ".." not in relative.parts,
        "directory path drift",
    )
    descriptor = os.open(
        repository_root,
        os.O_RDONLY | os.O_DIRECTORY | getattr(os, "O_NOFOLLOW", 0),
    )
    try:
        for component in relative.parts:
            try:
                next_descriptor = os.open(
                    component,
                    os.O_RDONLY | os.O_DIRECTORY | getattr(os, "O_NOFOLLOW", 0),
                    dir_fd=descriptor,
                )
            except FileNotFoundError:
                os.mkdir(component, 0o755, dir_fd=descriptor)
                next_descriptor = os.open(
                    component,
                    os.O_RDONLY | os.O_DIRECTORY | getattr(os, "O_NOFOLLOW", 0),
                    dir_fd=descriptor,
                )
            os.close(descriptor)
            descriptor = next_descriptor
        return descriptor
    except BaseException:
        os.close(descriptor)
        raise


def write_exclusive_at(directory_fd: int, name: str, value: Any) -> None:
    require("/" not in name and name not in {"", ".", ".."}, "leaf name drift")
    descriptor = os.open(
        name,
        os.O_WRONLY
        | os.O_CREAT
        | os.O_EXCL
        | getattr(os, "O_NOFOLLOW", 0),
        0o644,
        dir_fd=directory_fd,
    )
    try:
        payload = canonical_bytes(value)
        offset = 0
        while offset < len(payload):
            offset += os.write(descriptor, payload[offset:])
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def create_exclusive_directory(repository_root: Path, relative: Path) -> int:
    require(
        not relative.is_absolute() and ".." not in relative.parts,
        "exclusive directory path drift",
    )
    parent_fd = open_or_create_directory_chain(repository_root, relative.parent)
    try:
        os.mkdir(relative.name, 0o755, dir_fd=parent_fd)
        return os.open(
            relative.name,
            os.O_RDONLY | os.O_DIRECTORY | getattr(os, "O_NOFOLLOW", 0),
            dir_fd=parent_fd,
        )
    except FileExistsError as error:
        raise LaunchError("exclusive execution root already exists") from error
    finally:
        os.close(parent_fd)


def consume_external_lease(authority: dict[str, Any]) -> Path:
    lease = Path(authority["executionEnvelope"]["leasePath"])
    require(lease.is_absolute(), "execution lease must be absolute")
    descriptor = os.open(
        lease,
        os.O_WRONLY
        | os.O_CREAT
        | os.O_EXCL
        | getattr(os, "O_NOFOLLOW", 0),
        0o600,
    )
    try:
        payload = canonical_bytes(
            {
                "schema": 1,
                "grantId": authority["grantId"],
                "attemptId": authority["attemptId"],
                "executionAuthoritySHA256": authority["sha256"],
                "consumed": True,
            }
        )
        os.write(descriptor, payload)
        os.fsync(descriptor)
    finally:
        os.close(descriptor)
    return lease


def create_attempt_record(
    repository_root: Path,
    authority: dict[str, Any],
) -> tuple[int, dict[str, Any]]:
    relative = Path(authority["attemptRecordPath"])
    parent_fd = open_or_create_directory_chain(repository_root, relative.parent)
    leaf = relative.name
    try:
        record = {
            "schema": 1,
            "task": "PLAY-027",
            "direction": "north",
            "process": "A",
            "grantId": authority["grantId"],
            "attemptId": authority["attemptId"],
            "executionAuthority": {
                "path": authority["path"],
                "sha256": authority["sha256"],
                "publicationCommit": authority["publicationCommit"],
            },
            "schedule": authority["schedule"],
            "consumed": True,
            "maximumDCCChildStarts": 1,
            "sourceAuthority": False,
            "productionSelected": False,
        }
        write_exclusive_at(parent_fd, leaf, record)
        return parent_fd, record
    except FileExistsError as error:
        os.close(parent_fd)
        raise LaunchError("Integration-bound Process-A attempt was already consumed") from error


def write_attempt_terminal(
    terminal_directory_fd: int,
    authority: dict[str, Any],
    *,
    output_root_created: bool,
    terminal_receipt: dict[str, Any],
    process_receipt: dict[str, str] | None,
) -> dict[str, Any]:
    value = {
        "schema": 1,
        "task": "PLAY-027",
        "direction": "north",
        "process": "A",
        "grantId": authority["grantId"],
        "attemptId": authority["attemptId"],
        "outputRootCreated": output_root_created,
        "terminalReceipt": terminal_receipt,
        "processReceipt": process_receipt,
        "sourceAuthority": False,
        "productionSelected": False,
    }
    write_exclusive_at(terminal_directory_fd, "north-A.TERMINAL.json", value)
    return value


def create_output_root(
    repository_root: Path,
    contract: dict[str, Any],
    requested: Path,
) -> tuple[int, dict[str, int]]:
    relative = Path(contract["processOutputRoot"])
    require(requested.absolute() == (repository_root / relative).absolute(), "output root drift")
    parent_fd, leaf = open_parent_directory(repository_root, relative)
    try:
        os.mkdir(leaf, 0o755, dir_fd=parent_fd)
        root_fd = os.open(
            leaf,
            os.O_RDONLY | os.O_DIRECTORY | getattr(os, "O_NOFOLLOW", 0),
            dir_fd=parent_fd,
        )
    except FileExistsError as error:
        raise LaunchError("Process-A output root already exists") from error
    finally:
        os.close(parent_fd)
    root_stat = os.fstat(root_fd)
    return root_fd, {"device": root_stat.st_dev, "inode": root_stat.st_ino}


def capability_message(
    authority_secret: bytes,
    *,
    session_secret: bytes,
    public_payload: dict[str, Any],
) -> dict[str, Any]:
    signed = {
        **public_payload,
        "authorizationSecret": base64.b64encode(authority_secret).decode("ascii"),
        "sessionSecret": base64.b64encode(session_secret).decode("ascii"),
    }
    signature = hmac.new(
        authority_secret,
        canonical_bytes(signed),
        hashlib.sha256,
    ).hexdigest()
    return {**signed, "hmacSHA256": signature}


def terminal_disposition(
    *,
    child_pid: int | None,
    return_code: int | None,
    termination_reason: str,
    launcher_exception: str | None,
    sampled_peak_rss_kib: int,
    terminal_peak_rss_kib: int,
    observed_extra_members: set[int],
    remaining_members: list[dict[str, int]],
) -> dict[str, Any]:
    return {
        "childPID": child_pid,
        "returnCode": return_code,
        "terminationReason": termination_reason,
        "sampledAggregateGroupPeakRSSKiB": sampled_peak_rss_kib,
        "terminalChildTreeMaxRSSKiB": terminal_peak_rss_kib,
        "enforcedPeakRSSKiB": max(
            sampled_peak_rss_kib,
            terminal_peak_rss_kib,
        ),
        "observedExtraProcessGroupMembers": sorted(observed_extra_members),
        "postReapProcessGroupMembers": remaining_members,
        "postReapProcessGroupExhausted": not remaining_members,
        "terminalWaitModel": "darwin-os.wait4-exact-pid",
        "launcherException": launcher_exception,
    }


def run_one_child(
    repository_root: Path,
    contract_path: Path,
    schedule_path: Path,
    schedule_publication_commit: str,
    execution_authority_path: Path,
    execution_authority_publication_commit: str,
    trusted_integration_head: str,
    authorization_secret_fd: int,
    output_root: Path,
    *,
    _fault: Callable[[str], None] | None = None,
) -> int:
    def fault(stage: str) -> None:
        if _fault is not None:
            _fault(stage)

    HELPER_PROCESS_AUDIT.clear()
    contract = validate_execution_contract(repository_root, contract_path)
    normalized_schedule = normalize_repository_file(
        repository_root,
        schedule_path,
        "schedule",
    )
    authorization_secret = read_authorization_secret(authorization_secret_fd)
    authority = validate_execution_closure(
        repository_root,
        contract,
        execution_authority_path,
        execution_authority_publication_commit,
        normalized_schedule,
        schedule_publication_commit,
        output_root,
        authorization_secret,
        trusted_integration_head,
    )
    adapter_path = repository_root / contract["scheduleAdapter"]["consumer"]["path"]
    adapter = load_module(adapter_path, "play027_process_a_schedule_adapter")
    original_adapter_git_output = adapter.git_output
    original_adapter_git_bytes = adapter.git_bytes

    def audited_adapter_git_output(root: Path, arguments: list[str]) -> str:
        HELPER_PROCESS_AUDIT.append(
            {"class": "git-read-only", "argv": ["git", *arguments]}
        )
        return original_adapter_git_output(root, arguments)

    def audited_adapter_git_bytes(root: Path, arguments: list[str]) -> bytes:
        HELPER_PROCESS_AUDIT.append(
            {"class": "git-read-only", "argv": ["git", *arguments]}
        )
        return original_adapter_git_bytes(root, arguments)

    adapter.git_output = audited_adapter_git_output
    adapter.git_bytes = audited_adapter_git_bytes
    grant = adapter.consume_published_schedule(
        repository_root,
        repository_root / contract["scheduleAdapter"]["contract"]["path"],
        normalized_schedule,
        schedule_publication_commit,
    )
    plan = validate_grant_plan(contract, grant, output_root, repository_root)
    require(grant["grantId"] == authority["grantId"], "execution authority grant drift")
    require(grant["slotId"] == authority["slotId"], "execution authority slot drift")
    verify_blender_executable(contract)
    require(sys.platform == "darwin", "Process-A child launch requires Darwin")
    fault("lease")
    consume_external_lease(authority)
    terminal_directory_fd = create_exclusive_directory(
        repository_root,
        Path(authority["terminalRoot"]),
    )
    try:
        attempt_directory_fd, attempt_record = create_attempt_record(
            repository_root,
            authority,
        )
    except BaseException:
        os.close(terminal_directory_fd)
        raise
    output_root_fd = -1
    output_identity: dict[str, int] = {}
    try:
        fault("root")
        output_root_fd, output_identity = create_output_root(
            repository_root,
            contract,
            output_root,
        )
    except BaseException as error:
        disposition = terminal_disposition(
            child_pid=None,
            return_code=None,
            termination_reason=f"launcher-exception:{type(error).__name__}",
            launcher_exception=f"{type(error).__name__}: {error}",
            sampled_peak_rss_kib=0,
            terminal_peak_rss_kib=0,
            observed_extra_members=set(),
            remaining_members=[],
        )
        write_attempt_terminal(
            terminal_directory_fd,
            authority,
            output_root_created=False,
            terminal_receipt=disposition,
            process_receipt=None,
        )
        os.close(attempt_directory_fd)
        os.close(terminal_directory_fd)
        return 1
    capability_read_fd = -1
    capability_write_fd = -1
    session_secret = b""
    command: list[str] = []
    environment = os.environ.copy()
    environment.update(
        {
            "OMP_NUM_THREADS": "1",
            "OPENBLAS_NUM_THREADS": "1",
            "VECLIB_MAXIMUM_THREADS": "1",
        }
    )
    started = time.monotonic()
    sampled_peak_rss_kib = 0
    terminal_peak_rss_kib = 0
    observed_extra_members: set[int] = set()
    violation: str | None = None
    terminal_status: int | None = None
    terminal_usage: Any = None
    process: subprocess.Popen[bytes] | None = None
    process_pid: int | None = None
    return_code: int | None = None
    stdout = b""
    stderr = b""
    remaining_members: list[dict[str, int]] = []
    launcher_exception: str | None = None
    dcc_child_start_count = 0
    receipt_written = False
    stdout_file: Any = None
    stderr_file: Any = None
    try:
        fault("pipe")
        session_secret = secrets.token_bytes(32)
        capability_read_fd, capability_write_fd = os.pipe()
        child_grant = {
            "schema": 2,
            "task": contract["task"],
            "direction": contract["direction"],
            "process": contract["process"],
            "grantId": grant["grantId"],
            "slotId": grant["slotId"],
            "schedulePath": str(normalized_schedule.relative_to(repository_root)),
            "scheduleSHA256": sha256(normalized_schedule),
            "schedulePublicationCommit": schedule_publication_commit,
            "executionAuthorityPath": authority["path"],
            "executionAuthoritySHA256": authority["sha256"],
            "executionAuthorityPublicationCommit": authority["publicationCommit"],
            "trustedIntegrationHead": authority["closureValidation"]["trustedHead"],
            "workerHead": authority["closureValidation"]["workerHead"],
            "executionClosureValidatorSHA256": contract["executionClosure"]["validator"][
                "sha256"
            ],
            "contractSHA256": sha256(contract_path),
            "launcherSHA256": contract["launcher"]["sha256"],
            "launcherPID": os.getpid(),
            "runnerContractSHA256": contract["runnerContract"]["sha256"],
            "childEntrypointSHA256": contract["childEntrypoint"]["sha256"],
            "outputRoot": plan["outputRoot"],
            "outputRootDevice": output_identity["device"],
            "outputRootInode": output_identity["inode"],
            "authorizationSecretSHA256": authority["authorizationSecretSHA256"],
            "sessionSecretSHA256": sha256_bytes(session_secret),
            "attemptRecordPath": authority["attemptRecordPath"],
            "attemptRecordSHA256": sha256_bytes(canonical_bytes(attempt_record)),
            "maximumDCCChildStarts": 1,
            "currentAuthorityReplay": contract["currentAuthorityReplay"],
        }
        fault("grant")
        write_exclusive_at(output_root_fd, "CHILD-GRANT.json", child_grant)
        fault("command")
        command = build_child_command(
            repository_root,
            contract_path,
            contract,
            output_root_fd,
            capability_read_fd,
        )
        fault("temp")
        stdout_file = tempfile.TemporaryFile()
        stderr_file = tempfile.TemporaryFile()
        try:
            fault("popen")
            process = subprocess.Popen(
                command,
                cwd=repository_root,
                env=environment,
                stdout=stdout_file,
                stderr=stderr_file,
                start_new_session=True,
                pass_fds=(capability_read_fd, output_root_fd),
                close_fds=True,
            )
            process_pid = process.pid
            dcc_child_start_count = 1
            os.close(capability_read_fd)
            capability_read_fd = -1
            capability_payload = capability_message(
                authorization_secret,
                session_secret=session_secret,
                public_payload={
                "schema": 2,
                "grantId": grant["grantId"],
                "launcherPID": os.getpid(),
                "launcherSHA256": contract["launcher"]["sha256"],
                "scheduleSHA256": sha256(normalized_schedule),
                "schedulePublicationCommit": schedule_publication_commit,
                "executionAuthoritySHA256": authority["sha256"],
                "executionAuthorityPublicationCommit": authority["publicationCommit"],
                "trustedIntegrationHead": authority["closureValidation"][
                    "trustedHead"
                ],
                "workerHead": authority["closureValidation"]["workerHead"],
                "executionClosureValidatorSHA256": contract["executionClosure"][
                    "validator"
                ]["sha256"],
                "runnerContractSHA256": contract["runnerContract"]["sha256"],
                "currentAuthorityReplay": contract["currentAuthorityReplay"],
                "outputRootDevice": output_identity["device"],
                "outputRootInode": output_identity["inode"],
                },
            )
            os.write(capability_write_fd, canonical_bytes(capability_payload))
            os.close(capability_write_fd)
            capability_write_fd = -1
            while terminal_status is None:
                fault("sampler")
                members = process_group_snapshot(process.pid)
                sampled_peak_rss_kib = max(
                    sampled_peak_rss_kib,
                    sum(member["rssKiB"] for member in members),
                )
                observed_extra_members.update(
                    member["pid"]
                    for member in members
                    if member["pid"] != process.pid
                )
                waited_pid, waited_status, waited_usage = os.wait4(
                    process.pid,
                    os.WNOHANG,
                )
                if waited_pid == process.pid:
                    terminal_status = waited_status
                    terminal_usage = waited_usage
                    process.returncode = os.waitstatus_to_exitcode(waited_status)
                    break
                elapsed = time.monotonic() - started
                violation = enforce_resource_observation(
                    process.pid,
                    elapsed_seconds=elapsed,
                    sampled_peak_rss_kib=sampled_peak_rss_kib,
                    maximum_seconds=float(
                        contract["processEnvelope"]["timeoutSeconds"]
                    ),
                    maximum_rss_kib=int(
                        contract["processEnvelope"]["maximumProcessGroupRSSMiB"]
                    )
                    * 1024,
                    observed_extra_members=observed_extra_members,
                )
                if violation is not None:
                    _, terminal_status, terminal_usage = os.wait4(process.pid, 0)
                    process.returncode = os.waitstatus_to_exitcode(terminal_status)
                    break
                time.sleep(0.05)
            terminal_peak_rss_kib = terminal_rss_kib(terminal_usage)
            enforced_peak_rss_kib = max(
                sampled_peak_rss_kib,
                terminal_peak_rss_kib,
            )
            if (
                violation is None
                and enforced_peak_rss_kib
                > int(contract["processEnvelope"]["maximumProcessGroupRSSMiB"])
                * 1024
            ):
                violation = "terminal-rss-limit"
            remaining_members = process_group_snapshot(process.pid)
            if violation is None and remaining_members:
                violation = "post-reap-process-group-not-empty"
                terminate_group(process.pid)
            return_code = process.returncode
            fault("cleanup")
        except BaseException as error:
            launcher_exception = f"{type(error).__name__}: {error}"
            violation = f"launcher-exception:{type(error).__name__}"
            if process is not None:
                terminate_group(process.pid)
                try:
                    _, terminal_status, terminal_usage = os.wait4(process.pid, 0)
                    process.returncode = os.waitstatus_to_exitcode(terminal_status)
                    return_code = process.returncode
                    terminal_peak_rss_kib = terminal_rss_kib(terminal_usage)
                except ChildProcessError:
                    return_code = process.returncode
                try:
                    remaining_members = process_group_snapshot(process.pid)
                except LaunchError:
                    remaining_members = []
    except BaseException as error:
        if launcher_exception is None:
            launcher_exception = f"{type(error).__name__}: {error}"
            violation = f"launcher-exception:{type(error).__name__}"
    finally:
        for descriptor in (capability_read_fd, capability_write_fd):
            if descriptor >= 0:
                try:
                    os.close(descriptor)
                except OSError:
                    pass
        if stdout_file is not None:
            stdout_file.seek(0)
            stdout = stdout_file.read()
            stdout_file.close()
        if stderr_file is not None:
            stderr_file.seek(0)
            stderr = stderr_file.read()
            stderr_file.close()
    elapsed = time.monotonic() - started
    receipt = {
        "schema": 2,
        "task": contract["task"],
        "direction": contract["direction"],
        "process": contract["process"],
        "grantId": grant["grantId"],
        "attemptRecordPath": authority["attemptRecordPath"],
        "attemptRecordSHA256": sha256_bytes(canonical_bytes(attempt_record)),
        "executionAuthority": {
            "path": authority["path"],
            "sha256": authority["sha256"],
            "publicationCommit": authority["publicationCommit"],
        },
        "dccChildStartCount": dcc_child_start_count,
        "maximumDCCChildStarts": 1,
        "helperProcessCount": len(HELPER_PROCESS_AUDIT),
        "helperProcessInvocations": HELPER_PROCESS_AUDIT,
        "childArgv": command,
        "newProcessGroup": True,
        "elapsedSeconds": round(elapsed, 6),
        **terminal_disposition(
            child_pid=process_pid,
            return_code=return_code,
            termination_reason=violation
            or ("success" if return_code == 0 else "child-nonzero-exit"),
            launcher_exception=launcher_exception,
            sampled_peak_rss_kib=sampled_peak_rss_kib,
            terminal_peak_rss_kib=terminal_peak_rss_kib,
            observed_extra_members=observed_extra_members,
            remaining_members=remaining_members,
        ),
        "stdoutTail": stdout.decode("utf-8", errors="replace")[-4000:],
        "stderrTail": stderr.decode("utf-8", errors="replace")[-4000:],
        "renderAuthority": False,
        "sourceAuthority": False,
        "productionSelected": False,
    }
    process_receipt_binding: dict[str, str] | None = None
    try:
        write_exclusive_at(output_root_fd, "PROCESS-RECEIPT.json", receipt)
        receipt_written = True
        process_receipt_binding = {
            "path": str(Path(contract["processOutputRoot"]) / "PROCESS-RECEIPT.json"),
            "sha256": sha256_bytes(canonical_bytes(receipt)),
        }
    finally:
        try:
            write_attempt_terminal(
                terminal_directory_fd,
                authority,
                output_root_created=True,
                terminal_receipt=terminal_disposition(
                    child_pid=process_pid,
                    return_code=return_code,
                    termination_reason=violation
                    or ("success" if return_code == 0 else "child-nonzero-exit"),
                    launcher_exception=launcher_exception,
                    sampled_peak_rss_kib=sampled_peak_rss_kib,
                    terminal_peak_rss_kib=terminal_peak_rss_kib,
                    observed_extra_members=observed_extra_members,
                    remaining_members=remaining_members,
                ),
                process_receipt=process_receipt_binding,
            )
        finally:
            os.close(attempt_directory_fd)
            os.close(terminal_directory_fd)
            os.close(output_root_fd)
    require(receipt_written, "terminal Process-A receipt was not written")
    if violation is not None or return_code != 0:
        return 1
    return 0


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", required=True)
    parser.add_argument("--schedule", required=True)
    parser.add_argument("--schedule-publication-commit", required=True)
    parser.add_argument("--execution-authority", required=True)
    parser.add_argument("--execution-authority-publication-commit", required=True)
    parser.add_argument("--trusted-integration-head", required=True)
    parser.add_argument("--authorization-secret-fd", required=True, type=int)
    parser.add_argument("--output-root", required=True)
    return parser.parse_args()


def main() -> int:
    options = arguments()
    return run_one_child(
        Path(options.repository_root).resolve(strict=True),
        Path(options.contract),
        Path(options.schedule),
        options.schedule_publication_commit,
        Path(options.execution_authority),
        options.execution_authority_publication_commit,
        options.trusted_integration_head,
        options.authorization_secret_fd,
        Path(options.output_root),
    )


if __name__ == "__main__":
    sys.exit(main())
