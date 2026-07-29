#!/usr/bin/env python3
"""Prepare the PLAY-081 West source-stage v2 launch-bound packet.

The assembler is candidate-neutral and zero-pixel.  It writes nothing unless
all exact Integration authorities validate against the bound ``origin/master``
commit and all nine immutable A/B/C roots are distinct and absent.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator

from run_west_source import frozen_input_errors
from west_launch_authority import (
    SOURCE_SCHEMA_PATH,
    SOURCE_SCHEMA_SHA256,
    load_json,
    repository_path,
    sha256,
    validate_future_authorities,
    validate_output_root_isolation,
)


SOURCE_ROOT = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-081/"
    "industrial-l04-west-source-v01"
)
EVIDENCE_ROOT = (
    "docs/production/evidence/PLAY-081/industrial-l04-west-source-v01"
)
DEFAULT_CONTRACT = f"{SOURCE_ROOT}/RUNNER-CONTRACT.json"
CONTRACT_010_PATH = (
    "docs/production/decisions/CONTRACT-010-directional-building-art.md"
)
CONTRACT_010_SHA256 = (
    "0ee2d68a9dba4694d92a864bfeb5a91970c88fe87d893e1898de7b26d38609af"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", default=DEFAULT_CONTRACT)
    parser.add_argument("--mode", choices=("describe", "assemble"), required=True)
    return parser.parse_args()


def artifact(root: Path, relative: str) -> dict[str, str]:
    path = repository_path(root, relative)
    if not path.is_file():
        raise ValueError(f"missing artifact: {relative}")
    return {"path": relative, "sha256": sha256(path)}


def head_commit(root: Path) -> str:
    result = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=root,
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def json_bytes(value: dict[str, Any]) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


def bytes_sha256(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def no_overwrite_write(path: Path, value: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("xb") as handle:
        handle.write(value)


def authority_packet(contract: dict[str, Any]) -> dict[str, Any]:
    bridge = contract["coordinateBridge"]["v06"]
    source_stage = contract["sourceStage"]
    appearance = contract["appearanceLock"]
    material = contract["lockedMaterialMapping"]
    profile = source_stage["sourceProductionProfile"]
    return {
        "contract010": {
            "path": CONTRACT_010_PATH,
            "sha256": CONTRACT_010_SHA256,
        },
        "contract021": {
            "path": contract["governingContract"]["path"],
            "revision": contract["governingContract"]["revision"],
            "sha256": contract["governingContract"]["sha256"],
        },
        "directionBridge": {
            "documentPath": bridge["acceptancePath"],
            "sourceCandidate": bridge["sourceCandidateCommit"],
            "integratedProofCommit": bridge["integratedProofCommit"],
            "documentSha256": bridge["acceptanceSha256"],
            "mappingContractSha256": bridge["mappingContractSha256"],
            "coordinateSystem": "citysim_source_pixels_v1",
        },
        "appearanceLock": appearance,
        "lockedMaterialMapping": {
            key: material[key] for key in ("path", "commit", "sha256")
        },
        "sourceProductionProfile": {
            key: profile[key] for key in ("path", "commit", "sha256")
        },
        "nonAliasInput": source_stage["nonAliasInput"],
        "nonAliasLoader": source_stage["nonAliasLoader"],
        "semanticValidator": source_stage["semanticValidator"],
        "canonicalDecoder": source_stage["canonicalDecoder"],
    }


def launch_roots(contract: dict[str, Any]) -> dict[str, str]:
    return {
        process_id: contract["outputInventory"]["processes"][process_id][
            "directory"
        ]
        for process_id in ("A", "B", "C")
    }


def build_packet(
    root: Path,
    contract_relative: str,
    contract: dict[str, Any],
    guard_artifact: dict[str, str],
    isolation_artifact: dict[str, str],
) -> dict[str, Any]:
    launch_bound = contract["outputInventory"]["launchBound"]
    return {
        "schemaVersion": 2,
        "stage": "launch_bound",
        "identity": {
            "taskId": "PLAY-081",
            "direction": "west",
            "branch": "codex/citysim-world-art-west",
            "family": "industrial",
            "level": 4,
            "variant": 0,
            "logicalID": "industrial_l04_v0_west",
            "sourceKey": "industrial_l04/variant-0/west/source-v01",
            "sourceRoot": SOURCE_ROOT,
            "evidenceRoot": EVIDENCE_ROOT,
            "orientationTransform": "none",
            "fallbackSourceKey": None,
        },
        "lineage": {
            "publishedBaseline": contract["futureProductionAuthority"][
                "originMasterCommit"
            ],
            "cellContentCommit": head_commit(root),
        },
        "authorities": authority_packet(contract),
        "inputs": {
            "prelaunchHandoff": artifact(
                root,
                f"{EVIDENCE_ROOT}/WEST-ZERO-PIXEL-V2-HANDOFF.json",
            ),
            "frozenInputManifest": artifact(
                root,
                launch_bound["frozenInputManifest"],
            ),
            "runnerContract": artifact(root, contract_relative),
            "outputRoot": EVIDENCE_ROOT,
        },
        "launch": {
            "guardReceipt": guard_artifact,
            "result": "PASS",
            "authorizedProcesses": ["A", "B", "C"],
            "isolatedOutputRoots": launch_roots(contract),
            "allOutputRootsDistinct": True,
            "outputRootIsolationReceipt": isolation_artifact,
        },
        "completion": None,
        "candidateReadyForIndependentReview": False,
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
    }


def describe(root: Path, contract: dict[str, Any]) -> dict[str, Any]:
    authority = validate_future_authorities(root, contract)
    isolation = validate_output_root_isolation(
        root,
        contract,
        require_absent=True,
    )
    return {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "mode": "describe",
        "futurePacketStage": "launch_bound",
        "authority": authority,
        "outputRootIsolation": isolation,
        "packetWritten": False,
        "blenderProcessLaunches": 0,
        "blenderRenderApiCalls": 0,
        "normalizerInvocations": 0,
        "contactSheetInvocations": 0,
        "pixelFiles": 0,
        "passed": True,
    }


def assemble(
    root: Path,
    contract_relative: str,
    contract: dict[str, Any],
) -> tuple[int, dict[str, Any]]:
    frozen_errors = frozen_input_errors(root, contract)
    authority = validate_future_authorities(root, contract)
    isolation = validate_output_root_isolation(
        root,
        contract,
        require_absent=True,
    )
    errors = sorted(
        set(frozen_errors + authority["errors"] + isolation["errors"])
    )
    if errors:
        return 3, {
            "schemaVersion": 1,
            "taskId": "PLAY-081",
            "direction": "west",
            "mode": "assemble",
            "decision": "BLOCKED",
            "rejectionStage": "before_blender_process",
            "errors": errors,
            "packetWritten": False,
            "blenderProcessLaunches": 0,
            "blenderRenderApiCalls": 0,
            "pixelFiles": 0,
        }

    launch_bound = contract["outputInventory"]["launchBound"]
    guard_path = repository_path(root, launch_bound["guardReceipt"])
    isolation_path = repository_path(
        root,
        launch_bound["outputRootIsolationReceipt"],
    )
    packet_path = repository_path(root, launch_bound["packet"])
    for path in (guard_path, isolation_path, packet_path):
        if path.exists():
            return 3, {
                "schemaVersion": 1,
                "taskId": "PLAY-081",
                "direction": "west",
                "mode": "assemble",
                "decision": "BLOCKED",
                "rejectionStage": "before_receipt_write",
                "errors": [f"NO_OVERWRITE:{path.relative_to(root)}"],
                "packetWritten": False,
                "blenderProcessLaunches": 0,
                "blenderRenderApiCalls": 0,
                "pixelFiles": 0,
            }

    guard_receipt = {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "result": "PASS",
        "rejectionStage": "before_blender_process",
        "originMaster": authority["originMaster"],
        "appearanceLockCommit": authority["appearanceLockCommit"],
        "sourceProductionProfileCommit": authority[
            "sourceProductionProfileCommit"
        ],
        "authorizedProcesses": ["A", "B", "C"],
        "maximumConcurrentDccProcesses": 2,
        "exceptionOwner": "Integration",
        "blenderProcessLaunches": 0,
        "blenderRenderApiCalls": 0,
        "pixelFiles": 0,
    }
    isolation_receipt = {
        **isolation,
        "result": "PASS",
        "authorizedProcesses": ["A", "B", "C"],
    }
    guard_data = json_bytes(guard_receipt)
    isolation_data = json_bytes(isolation_receipt)
    packet = build_packet(
        root,
        contract_relative,
        contract,
        {
            "path": launch_bound["guardReceipt"],
            "sha256": bytes_sha256(guard_data),
        },
        {
            "path": launch_bound["outputRootIsolationReceipt"],
            "sha256": bytes_sha256(isolation_data),
        },
    )
    schema_path = repository_path(root, SOURCE_SCHEMA_PATH)
    if sha256(schema_path) != SOURCE_SCHEMA_SHA256:
        raise ValueError("source-stage schema SHA-256 drift")
    schema = load_json(schema_path)
    Draft202012Validator.check_schema(schema)
    schema_errors = sorted(
        Draft202012Validator(schema).iter_errors(packet),
        key=lambda error: list(error.path),
    )
    if schema_errors:
        error = schema_errors[0]
        raise ValueError(
            f"launch-bound structural rejection {list(error.path)}: "
            f"{error.message}"
        )
    packet_data = json_bytes(packet)
    no_overwrite_write(guard_path, guard_data)
    no_overwrite_write(isolation_path, isolation_data)
    no_overwrite_write(packet_path, packet_data)
    return 0, {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "mode": "assemble",
        "decision": "PASS",
        "packet": {
            "path": launch_bound["packet"],
            "sha256": bytes_sha256(packet_data),
            "stage": "launch_bound",
        },
        "packetWritten": True,
        "blenderProcessLaunches": 0,
        "blenderRenderApiCalls": 0,
        "pixelFiles": 0,
    }


def main() -> int:
    args = parse_args()
    root = Path(args.repository_root).resolve()
    contract_path = repository_path(root, args.contract)
    contract = load_json(contract_path)
    if args.mode == "describe":
        result = describe(root, contract)
        code = 0
    else:
        code, result = assemble(root, args.contract, contract)
    print(json.dumps(result, indent=2, sort_keys=True))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
