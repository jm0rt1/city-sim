#!/usr/bin/env python3
"""Fail-closed zero-child schedule consumer for future North v12 Process A."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any


SOURCE_ROOT = Path(
    "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
    "industrial-l04-north-art-v12/process-a-schedule-adapter-v01"
)
CONTRACT_RELATIVE = SOURCE_ROOT / "ADAPTER-CONTRACT.json"
ADAPTER_RELATIVE = SOURCE_ROOT / "consume_north_process_a_schedule.py"
INTEGRATION_SCHEDULE_ROOT = Path("docs/production/evidence/INTEGRATION")
MISSING_SCHEDULE_REASON_CODE = "MISSING_PUBLISHED_SCHEDULE"
EXPECTED_CONTRACT_FIELDS = {
    "schema",
    "task",
    "batch",
    "direction",
    "process",
    "phase",
    "branch",
    "publishedBaseCommit",
    "claim",
    "currentAuthorityReplay",
    "processAPrelaunchAuthority",
    "directionScheduleAdapter",
    "processAOrchestrator",
    "adapterAuthority",
    "scheduleSchema",
    "scheduleValidator",
    "familyContract",
    "frozenNorthV12Inputs",
    "expectedExclusiveRoots",
    "expectedSlotId",
    "expectedQueue",
    "maximumChildStarts",
    "orchestratorOnly",
    "directLowLevelInvocationAllowed",
    "adapterMode",
    "blenderChildStartCount",
    "dccProcessCount",
    "renderInvocationCount",
    "sourcePixelCount",
    "sourceAuthority",
    "candidateReadyForIndependentReview",
    "productionSelected",
}
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


class AdapterError(ValueError):
    """A fail-closed schedule or immutable-binding rejection."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AdapterError(message)


def canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, indent=2, sort_keys=True, separators=(",", ": "))
        + "\n"
    ).encode("utf-8")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"JSON object required: {path}")
    return value


def resolve_regular(repository_root: Path, relative: str, label: str) -> Path:
    require(relative and not relative.startswith("/"), f"{label} path must be repository-relative")
    lexical = repository_root / relative
    current = repository_root
    for component in Path(relative).parts:
        current = current / component
        require(not current.is_symlink(), f"{label} path contains a symlink")
    resolved = lexical.resolve(strict=True)
    require(resolved.is_relative_to(repository_root), f"{label} escapes repository")
    require(resolved.is_file(), f"{label} is not a regular file")
    return resolved


def verify_file_binding(
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
        require(binding["sha256"] == expected_sha256, f"{label} expected hash drift")
    path = resolve_regular(repository_root, binding["path"], label)
    require(sha256(path) == binding["sha256"], f"{label} hash is stale")
    return path


def git_output(repository_root: Path, arguments: list[str]) -> str:
    allowed = {"branch", "cat-file", "merge-base", "show", "status"}
    require(arguments and arguments[0] in allowed, "unapproved Git operation")
    result = subprocess.run(
        ["git", *arguments],
        cwd=repository_root,
        capture_output=True,
        text=True,
        check=False,
    )
    require(result.returncode == 0, f"Git check failed: {' '.join(arguments)}")
    return result.stdout.strip()


def git_bytes(repository_root: Path, arguments: list[str]) -> bytes:
    allowed = {"show"}
    require(arguments and arguments[0] in allowed, "unapproved binary Git operation")
    result = subprocess.run(
        ["git", *arguments],
        cwd=repository_root,
        capture_output=True,
        check=False,
    )
    require(result.returncode == 0, f"Git check failed: {' '.join(arguments)}")
    return result.stdout


def assert_commit_ancestor(repository_root: Path, commit: str, label: str) -> None:
    require(
        len(commit) == 40
        and all(character in "0123456789abcdef" for character in commit),
        f"{label} must be a full commit",
    )
    git_output(repository_root, ["cat-file", "-e", f"{commit}^{{commit}}"])
    git_output(repository_root, ["merge-base", "--is-ancestor", commit, "HEAD"])


def assert_commit_ancestor_of(
    repository_root: Path,
    ancestor: str,
    descendant: str,
    label: str,
) -> None:
    assert_commit_ancestor(repository_root, ancestor, f"{label}.ancestor")
    require(
        len(descendant) == 40
        and all(character in "0123456789abcdef" for character in descendant),
        f"{label}.descendant must be a full commit",
    )
    git_output(repository_root, ["cat-file", "-e", f"{descendant}^{{commit}}"])
    git_output(repository_root, ["merge-base", "--is-ancestor", descendant, "HEAD"])
    require(ancestor != descendant, f"{label} requires a preexisting authority commit")
    git_output(repository_root, ["merge-base", "--is-ancestor", ancestor, descendant])


def load_shared_validator(repository_root: Path, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(
        "play027_integration_schedule_validator",
        path,
    )
    require(spec is not None and spec.loader is not None, "schedule validator import failed")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    require(callable(getattr(module, "validate", None)), "schedule validator entrypoint missing")
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
        verify_file_binding(
            repository_root,
            value[label],
            f"currentAuthorityReplay.{label}",
            expected_path=EXPECTED_CURRENT_AUTHORITY_REPLAY[label]["path"],
            expected_sha256=EXPECTED_CURRENT_AUTHORITY_REPLAY[label]["sha256"],
        )
    loader_path = repository_root / value["nonAliasLoader"]["path"]
    spec = importlib.util.spec_from_file_location(
        "play027_current_non_alias_loader",
        loader_path,
    )
    require(spec is not None and spec.loader is not None, "non-alias loader import failed")
    loader = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loader)
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


def validate_contract(repository_root: Path, contract_path: Path) -> dict[str, Any]:
    expected = (repository_root / CONTRACT_RELATIVE).resolve(strict=True)
    require(contract_path.resolve(strict=True) == expected, "exact adapter contract required")
    contract = load_json(expected)
    require(set(contract) == EXPECTED_CONTRACT_FIELDS, "adapter contract fields drift")
    exact = {
        "schema": 1,
        "task": "PLAY-027",
        "batch": "industrial_l04_directional_family",
        "direction": "north",
        "process": "A",
        "phase": "prelock_north_a",
        "branch": "codex/citysim-world-art",
        "publishedBaseCommit": "aaee294718a8176b70a4688b738b517f216dd3a7",
        "expectedSlotId": "dcc-1",
        "expectedQueue": ["north:A"],
        "maximumChildStarts": 1,
        "orchestratorOnly": True,
        "directLowLevelInvocationAllowed": False,
        "adapterMode": "validate-and-return-grant-plan-only",
        "blenderChildStartCount": 0,
        "dccProcessCount": 0,
        "renderInvocationCount": 0,
        "sourcePixelCount": 0,
        "sourceAuthority": False,
        "candidateReadyForIndependentReview": False,
        "productionSelected": False,
    }
    for field, value in exact.items():
        require(contract[field] == value, f"adapter contract drift: {field}")
    require(
        contract["expectedExclusiveRoots"]
        == [
            "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v12",
            "docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v12",
        ],
        "exclusive root contract drift",
    )
    bindings = {
        "claim": (
            "docs/production/claims/PLAY-027.world-art.md",
            "53efe6f2f7931fa50cfd20af48892ea4237a4ddc4a7ec645696f0d4f4fb420a0",
        ),
        "processAPrelaunchAuthority": (
            "docs/production/evidence/INTEGRATION/"
            "INDUSTRIAL-L04-NORTH-V12-PROCESS-A-PRELAUNCH-AUTHORITY.md",
            "889fd6f87a0d7eb112fe392d66901e927658a86a6d3aa311e53178d61cb4725e",
        ),
        "processAOrchestrator": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
            "industrial-l04-north-art-v12/process-a-execution-v01/"
            "launch_north_process_a.py",
            "64f83eb87cb7896bd7c4b5e5f703b37d63ab54c06136b7064622b5b9c5b7e7ed",
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
        "scheduleValidator": (
            ".agents/skills/operate-citysim-integration/scripts/"
            "validate_industrial_l04_parallel_execution_schedule_v1.py",
            "086ff2f2cb7d0c030d0039b48b3b66f7e6c314dd97a705b8f0a8a41fda0bbb04",
        ),
        "familyContract": (
            "docs/production/decisions/CONTRACT-010-directional-building-art.md",
            "0ee2d68a9dba4694d92a864bfeb5a91970c88fe87d893e1898de7b26d38609af",
        ),
    }
    for label, (path, digest) in bindings.items():
        verify_file_binding(
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
    verify_file_binding(
        repository_root,
        contract["directionScheduleAdapter"],
        "directionScheduleAdapter",
        expected_path=str(ADAPTER_RELATIVE),
    )
    frozen = contract["frozenNorthV12Inputs"]
    require(
        isinstance(frozen, dict)
        and set(frozen)
        == {
            "scene",
            "materials",
            "loweringContract",
            "importer",
            "lowerer",
            "acceptedStaticBContract",
        },
        "frozen North v12 input inventory drift",
    )
    for label, binding in frozen.items():
        verify_file_binding(repository_root, binding, f"frozenNorthV12Inputs.{label}")
    assert_commit_ancestor(repository_root, contract["publishedBaseCommit"], "publishedBaseCommit")
    branch = git_output(repository_root, ["branch", "--show-current"])
    require(branch == contract["branch"], "attached branch mismatch")
    return contract


def schedule_direction(schedule: dict[str, Any], direction: str) -> dict[str, Any]:
    matches = [
        grant
        for grant in schedule["directionGrants"]
        if grant.get("direction") == direction
    ]
    require(len(matches) == 1, "exact North direction grant required")
    return matches[0]


def process_grant(direction: dict[str, Any], process: str) -> dict[str, Any]:
    matches = [
        grant for grant in direction["processes"] if grant.get("process") == process
    ]
    require(len(matches) == 1, "exact Process A grant required")
    return matches[0]


def validate_north_grant(
    repository_root: Path,
    contract: dict[str, Any],
    schedule: dict[str, Any],
) -> dict[str, Any]:
    require(schedule["phase"] == contract["phase"], "wrong schedule phase")
    require(schedule["batch"] == contract["batch"], "wrong schedule batch")
    require(schedule["appearanceLock"] is None, "prelock appearance lock must be absent")
    require(
        schedule["sourceProductionProfile"] is None,
        "prelock source-production profile must be absent",
    )
    require(
        schedule["familyContract"] == contract["familyContract"],
        "family contract binding drift",
    )
    assert_commit_ancestor(
        repository_root,
        schedule["integrationAuthorityCommit"],
        "integrationAuthorityCommit",
    )
    direction = schedule_direction(schedule, contract["direction"])
    require(direction["claim"] == contract["task"], "wrong direction claim")
    require(direction["branch"] == contract["branch"], "wrong direction branch")
    require(direction["claimSha256"] == contract["claim"]["sha256"], "claim hash drift")
    require(direction["baseCommit"] == contract["publishedBaseCommit"], "base commit drift")
    require(
        direction["exclusiveRoots"] == contract["expectedExclusiveRoots"],
        "exclusive roots drift",
    )
    verify_file_binding(
        repository_root,
        contract["processAOrchestrator"],
        "processAOrchestrator",
    )
    require(
        direction["orchestrator"] == contract["directionScheduleAdapter"],
        "direction schedule-adapter binding drift",
    )
    expected_orchestrator = contract["processAOrchestrator"]
    grant = process_grant(direction, contract["process"])
    require(grant["state"] == "granted", "North Process A grant is blocked")
    require(grant["slotId"] == contract["expectedSlotId"], "DCC slot drift")
    require(
        grant["maximumChildStarts"] == contract["maximumChildStarts"],
        "child-start limit drift",
    )
    require(grant["orchestratorOnly"] is True, "orchestrator-only gate disabled")
    require(
        grant["directLowLevelInvocationAllowed"] is False,
        "direct low-level invocation enabled",
    )
    envelope = schedule["computeEnvelope"]
    require(envelope["maximumSimultaneousDCCProcesses"] == 1, "prelock DCC cap drift")
    require(envelope["slotIds"] == [contract["expectedSlotId"]], "slot inventory drift")
    require(envelope["queueOrder"] == contract["expectedQueue"], "queue order drift")
    return {
        "schema": 1,
        "task": contract["task"],
        "batch": contract["batch"],
        "phase": contract["phase"],
        "direction": contract["direction"],
        "process": contract["process"],
        "grantId": grant["grantId"],
        "slotId": grant["slotId"],
        "maximumChildStarts": grant["maximumChildStarts"],
        "orchestrator": expected_orchestrator,
        "exclusiveRoots": direction["exclusiveRoots"],
        "integrationAuthorityCommit": schedule["integrationAuthorityCommit"],
        "publishedBaseCommit": direction["baseCommit"],
        "claimSHA256": direction["claimSha256"],
        "currentAuthorityReplay": contract["currentAuthorityReplay"],
        "frozenNorthV12Inputs": contract["frozenNorthV12Inputs"],
        "adapterMode": contract["adapterMode"],
        "directLowLevelInvocationAllowed": False,
        "blenderChildStartCount": 0,
        "dccProcessCount": 0,
        "renderInvocationCount": 0,
        "sourcePixelCount": 0,
        "grantValidated": True,
        "processStarted": False,
        "sourceAuthority": False,
        "candidateReadyForIndependentReview": False,
        "productionSelected": False,
    }


def verify_published_schedule(
    repository_root: Path,
    schedule_path: Path,
    schedule: dict[str, Any],
    schedule_publication_commit: str,
) -> None:
    integration_root = (repository_root / INTEGRATION_SCHEDULE_ROOT).resolve(strict=True)
    lexical = schedule_path.absolute()
    require(lexical.is_relative_to(repository_root), "schedule path escapes repository")
    current = repository_root
    for component in lexical.relative_to(repository_root).parts:
        current = current / component
        require(not current.is_symlink(), "schedule path contains a symlink")
    resolved = lexical.resolve(strict=True)
    require(resolved.is_relative_to(integration_root), "schedule is outside Integration authority root")
    relative = resolved.relative_to(repository_root)
    assert_commit_ancestor_of(
        repository_root,
        schedule["integrationAuthorityCommit"],
        schedule_publication_commit,
        "schedulePublication",
    )
    status = git_output(
        repository_root,
        ["status", "--porcelain=v1", "--", str(relative)],
    )
    require(not status, "published schedule worktree bytes are dirty")
    tracked = git_bytes(
        repository_root,
        ["show", f"{schedule_publication_commit}:{relative}"],
    )
    require(tracked == resolved.read_bytes(), "schedule bytes are not frozen at publication commit")


def consume_published_schedule(
    repository_root: Path,
    contract_path: Path,
    schedule_path: Path,
    schedule_publication_commit: str,
) -> dict[str, Any]:
    repository_root = repository_root.resolve(strict=True)
    contract = validate_contract(repository_root, contract_path)
    schedule_path = schedule_path.absolute()
    try:
        schedule = load_json(schedule_path)
    except FileNotFoundError:
        schedule_label = (
            schedule_path.relative_to(repository_root).as_posix()
            if schedule_path.is_relative_to(repository_root)
            else "<outside-repository>"
        )
        raise AdapterError(
            f"{MISSING_SCHEDULE_REASON_CODE}: {schedule_label}"
        ) from None
    validator_path = verify_file_binding(
        repository_root,
        contract["scheduleValidator"],
        "scheduleValidator",
    )
    validator = load_shared_validator(repository_root, validator_path)
    validator.validate(repository_root, schedule_path)
    verify_published_schedule(
        repository_root,
        schedule_path,
        schedule,
        schedule_publication_commit,
    )
    return validate_north_grant(repository_root, contract, schedule)


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", required=True)
    parser.add_argument("--schedule", required=True)
    parser.add_argument("--schedule-publication-commit", required=True)
    return parser.parse_args()


def main() -> int:
    options = arguments()
    try:
        result = consume_published_schedule(
            Path(options.repository_root),
            Path(options.contract),
            Path(options.schedule),
            options.schedule_publication_commit,
        )
    except (OSError, json.JSONDecodeError, AdapterError, ValueError) as error:
        print(
            json.dumps(
                {
                    "result": "BLOCKED",
                    "reason": str(error),
                    "blenderChildStartCount": 0,
                    "dccProcessCount": 0,
                    "renderInvocationCount": 0,
                    "sourcePixelCount": 0,
                },
                sort_keys=True,
            )
        )
        return 1
    print(json.dumps({"result": "VALIDATED_GRANT_PLAN", **result}, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
