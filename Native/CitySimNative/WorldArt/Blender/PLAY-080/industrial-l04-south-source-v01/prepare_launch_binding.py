#!/usr/bin/env python3
"""Emit the PLAY-080 v2 launch bundle only after exact authority validation."""

from __future__ import annotations

import argparse
import hashlib
import hmac
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator

import run_production


SOURCE_DIR = Path(__file__).resolve().parent
REPOSITORY_ROOT = SOURCE_DIR.parents[5]
DEFAULT_CONTRACT = SOURCE_DIR / "runner-contract.json"
HEX_40 = re.compile(r"^[0-9a-f]{40}$")
SCHEMA_SHA256 = (
    "85f6a2824c273a1e63354df79a97e5a59c2909a68771613b325664d649ac53ec"
)
SCHEMA_PATH = (
    "docs/production/evidence/INTEGRATION/"
    "industrial-l04-source-stage-handoff-schema-v2.json"
)


class LaunchBindingRejected(RuntimeError):
    def __init__(self, code: str, detail: Any):
        super().__init__(code)
        self.code = code
        self.detail = detail


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise LaunchBindingRejected("INVALID_JSON_OBJECT", str(path))
    return value


def encode_json(value: dict[str, Any]) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def execution_capability_payload(authority: dict[str, Any]) -> bytes:
    task = authority["task"]
    grant = authority["grant"]
    capability = authority["authentication"]["childCapability"]
    value = {
        "audience": capability["audience"],
        "authorityPublicationCommit": authority["_validated"][
            "authorityPublicationCommit"
        ],
        "boundGrantId": capability["boundGrantId"],
        "capabilityId": capability["capabilityId"],
        "direction": task["direction"],
        "process": grant["process"],
        "queueId": grant["queueId"],
        "slotId": grant["slotId"],
        "taskId": task["taskId"],
    }
    return json.dumps(
        value, separators=(",", ":"), sort_keys=True
    ).encode("utf-8")


def validate_execution_closure(
    authority: dict[str, Any],
    shared_receipt: dict[str, Any],
    secret: bytes | None,
    seen_capabilities: set[str],
) -> dict[str, Any]:
    """Authenticate one validation-only attempt and enter the runner boundary."""

    if not secret:
        raise LaunchBindingRejected("MISSING_ANONYMOUS_PIPE_SECRET", None)
    validated = authority.get("_validated", {})
    expected_validation = {
        key: shared_receipt.get(key)
        for key in (
            "authorityPublicationCommit",
            "trustedHead",
            "workerHead",
        )
    }
    if validated != expected_validation:
        raise LaunchBindingRejected(
            "SHARED_VALIDATION_RECEIPT_MISMATCH",
            {"expected": validated, "actual": expected_validation},
        )
    roots = authority.get("exclusiveRoots", {})
    anchors = {
        "output": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-080/"
            "industrial-l04-south-source-v01/outputs/"
        ),
        "evidence": (
            "docs/production/evidence/PLAY-080/"
            "industrial-l04-south-source-v01/evidence/"
        ),
        "attempt": (
            "docs/production/evidence/PLAY-080/"
            "industrial-l04-south-source-v01/attempts/"
        ),
        "terminal": (
            "docs/production/evidence/PLAY-080/"
            "industrial-l04-south-source-v01/terminals/"
        ),
    }
    if set(roots) != set(anchors) or any(
        not isinstance(roots.get(role), str)
        or not roots[role].startswith(anchor)
        or any(part in {"", ".", ".."} for part in Path(roots[role]).parts)
        for role, anchor in anchors.items()
    ):
        raise LaunchBindingRejected("WRONG_DIRECTION_EXCLUSIVE_ROOT", roots)
    authentication = authority.get("authentication", {})
    capability = authentication.get("childCapability", {})
    if hashlib.sha256(secret).hexdigest() != authentication.get("secretSha256"):
        raise LaunchBindingRejected("FORGED_ANONYMOUS_PIPE_SECRET", None)
    capability_id = capability.get("capabilityId")
    if not isinstance(capability_id, str) or not capability_id:
        raise LaunchBindingRejected("MALFORMED_CAPABILITY_ID", capability_id)
    if capability_id in seen_capabilities:
        raise LaunchBindingRejected("REPLAYED_EXECUTION_CAPABILITY", capability_id)
    payload = execution_capability_payload(authority)
    if hashlib.sha256(payload).hexdigest() != capability.get("payloadSha256"):
        raise LaunchBindingRejected("CAPABILITY_PAYLOAD_MISMATCH", None)
    expected_mac = hmac.new(secret, payload, hashlib.sha256).hexdigest()
    if not hmac.compare_digest(expected_mac, capability.get("macSha256", "")):
        raise LaunchBindingRejected("FORGED_EXECUTION_CAPABILITY", None)
    expected_orchestrator = (
        DEFAULT_CONTRACT.parent / "prepare_launch_binding.py"
    ).relative_to(REPOSITORY_ROOT).as_posix()
    if (
        authority.get("artifacts", {})
        .get("highLevelOrchestrator", {})
        .get("path")
        != expected_orchestrator
    ):
        raise LaunchBindingRejected("WRONG_HIGH_LEVEL_ORCHESTRATOR", None)
    seen_capabilities.add(capability_id)
    runner_receipt = run_production.validate_authenticated_execution_boundary(
        authority,
        shared_receipt,
        authenticated_by_orchestrator=True,
    )
    return {
        "schema": "citysim.play-080.south-execution-closure.v1",
        "result": "PASS_VALIDATION_ONLY_ZERO_CHILD",
        "authority": {
            "path": shared_receipt["authorityPath"],
            "publicationCommit": shared_receipt["authorityPublicationCommit"],
            "trustedHead": shared_receipt["trustedHead"],
            "workerHead": shared_receipt["workerHead"],
        },
        "grant": {
            key: authority["grant"][key]
            for key in ("grantId", "process", "queueId", "slotId")
        },
        "exclusiveRoots": authority["exclusiveRoots"],
        "authentication": {
            "secretTransport": "anonymous_pipe",
            "rawSecretPersisted": False,
            "capabilityId": capability_id,
            "oneTime": True,
            "replayAllowed": False,
        },
        "runnerBoundary": runner_receipt,
        "activity": {
            "childrenStarted": 0,
            "dccStarts": 0,
            "renders": 0,
            "pixels": 0,
            "liveLeases": 0,
        },
        "sourceReady": False,
        "productionSelected": False,
    }


def write_once(path: Path, content: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        with path.open("xb") as handle:
            handle.write(content)
    except FileExistsError as error:
        raise LaunchBindingRejected(
            "LAUNCH_BUNDLE_ALREADY_EXISTS",
            path.relative_to(REPOSITORY_ROOT).as_posix(),
        ) from error


def repo_path(value: str) -> Path:
    path = (REPOSITORY_ROOT / value).resolve()
    try:
        path.relative_to(REPOSITORY_ROOT)
    except ValueError as error:
        raise LaunchBindingRejected("PATH_OUTSIDE_REPOSITORY", value) from error
    return path


def git(*arguments: str, check: bool = True) -> str:
    result = subprocess.run(
        ["git", "-C", str(REPOSITORY_ROOT), *arguments],
        check=False,
        capture_output=True,
        text=True,
    )
    if check and result.returncode:
        raise LaunchBindingRejected(
            "GIT_COMMAND_FAILED",
            {"arguments": arguments, "stderr": result.stderr.strip()},
        )
    return result.stdout.strip()


def require_ancestor(older: str, newer: str, label: str) -> None:
    if HEX_40.fullmatch(older) is None:
        raise LaunchBindingRejected("INVALID_AUTHORITY_COMMIT", {label: older})
    result = subprocess.run(
        ["git", "-C", str(REPOSITORY_ROOT), "merge-base", "--is-ancestor", older, newer],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if result.returncode:
        raise LaunchBindingRejected(
            "AUTHORITY_ANCESTRY_MISMATCH",
            {"label": label, "older": older, "newer": newer},
        )


def require_file_at_commit(
    commit: str, path: str, expected_sha256: str, label: str
) -> None:
    result = subprocess.run(
        ["git", "-C", str(REPOSITORY_ROOT), "show", f"{commit}:{path}"],
        check=False,
        capture_output=True,
    )
    if result.returncode:
        raise LaunchBindingRejected(
            "AUTHORITY_FILE_NOT_IN_COMMIT",
            {"label": label, "commit": commit, "path": path},
        )
    actual = sha256_bytes(result.stdout)
    if actual != expected_sha256:
        raise LaunchBindingRejected(
            "AUTHORITY_COMMIT_CONTENT_DRIFT",
            {"label": label, "expected": expected_sha256, "actual": actual},
        )


def committed_artifact(
    record: dict[str, Any], label: str, origin_master: str, head: str
) -> dict[str, str]:
    required = ("path", "commit", "sha256")
    missing = [field for field in required if not record.get(field)]
    if missing:
        raise LaunchBindingRejected(
            f"MISSING_{label.upper()}",
            {"missingFields": missing},
        )
    path = repo_path(record["path"])
    if not path.is_file() or sha256(path) != record["sha256"]:
        raise LaunchBindingRejected("AUTHORITY_SHA_DRIFT", label)
    require_ancestor(record["commit"], origin_master, f"{label}:origin/master")
    require_ancestor(record["commit"], head, f"{label}:HEAD")
    require_file_at_commit(
        record["commit"], record["path"], record["sha256"], label
    )
    return {
        "path": record["path"],
        "commit": record["commit"],
        "sha256": record["sha256"],
    }


def appearance_authority(
    contract: dict[str, Any], origin_master: str, head: str
) -> dict[str, str]:
    lock = contract.get("appearanceLock", {})
    fields = (
        "documentPath",
        "appearanceLockCommit",
        "appearanceLockSha256",
        "northProcessASourceSha256",
        "northProcessADecodedRgbaSha256",
    )
    missing = [field for field in fields if not lock.get(field)]
    if missing:
        raise LaunchBindingRejected(
            "MISSING_APPEARANCE_LOCK", {"missingFields": missing}
        )
    record = {
        "path": lock["documentPath"],
        "commit": lock["appearanceLockCommit"],
        "sha256": lock["appearanceLockSha256"],
    }
    committed_artifact(record, "appearanceLock", origin_master, head)
    document = load_json(repo_path(lock["documentPath"]))
    expected = {
        "commit": lock["appearanceLockCommit"],
        "northProcessASourceSha256": lock["northProcessASourceSha256"],
        "northProcessADecodedRgbaSha256": lock[
            "northProcessADecodedRgbaSha256"
        ],
    }
    if any(document.get(key) != value for key, value in expected.items()):
        raise LaunchBindingRejected("WRONG_APPEARANCE_LOCK", expected)
    return {
        "documentPath": lock["documentPath"],
        "commit": lock["appearanceLockCommit"],
        "documentSha256": lock["appearanceLockSha256"],
        "northProcessASourceSha256": lock["northProcessASourceSha256"],
        "northProcessADecodedRgbaSha256": lock[
            "northProcessADecodedRgbaSha256"
        ],
    }


def validate_source_profile(
    profile_record: dict[str, str],
    appearance: dict[str, str],
    material: dict[str, str],
    contract: dict[str, Any],
) -> dict[str, Any]:
    profile = load_json(repo_path(profile_record["path"]))
    expected_keys = {
        "schema",
        "familyIdentity",
        "appearanceLock",
        "lockedMaterialMapping",
        "sourceStageSchema",
        "directionProcesses",
        "computeEnvelope",
        "grants",
    }
    if set(profile) != expected_keys:
        raise LaunchBindingRejected(
            "SOURCE_PROFILE_SCHEMA_DRIFT", sorted(profile)
        )
    expected = {
        "schema": "citysim.integration.world-art-source-production-profile.v1",
        "familyIdentity": {"family": "industrial", "level": 4, "variant": 0},
        "appearanceLock": appearance,
        "lockedMaterialMapping": material,
        "sourceStageSchema": contract["authorities"]["sourceStageHandoffSchema"],
        "directionProcesses": {
            "north": ["B", "C"],
            "east": ["A", "B", "C"],
            "south": ["A", "B", "C"],
            "west": ["A", "B", "C"],
        },
        "computeEnvelope": {
            "maximumConcurrentDccProcesses": 2,
            "exceptionOwner": "Integration",
        },
        "grants": {
            "sourceAcceptance": False,
            "rendererAdmission": False,
            "productionSelection": False,
            "shippingActivation": False,
        },
    }
    mismatches = {
        key: {"expected": value, "actual": profile.get(key)}
        for key, value in expected.items()
        if profile.get(key) != value
    }
    if mismatches:
        raise LaunchBindingRejected("SOURCE_PROFILE_BINDING_DRIFT", mismatches)
    return profile


def artifact(path: str, content: bytes | None = None) -> dict[str, str]:
    return {
        "path": path,
        "sha256": sha256_bytes(content) if content is not None else sha256(repo_path(path)),
    }


def build_packet(
    contract: dict[str, Any],
    head: str,
    appearance: dict[str, str],
    material: dict[str, str],
    profile: dict[str, str],
    manifest_artifact: dict[str, str],
    guard_artifact: dict[str, str],
    roots_artifact: dict[str, str],
) -> dict[str, Any]:
    bridge = contract["coordinateBridge"]
    plan = contract["launchPlan"]
    authorities = contract["authorities"]
    return {
        "schemaVersion": 2,
        "stage": "launch_bound",
        "identity": {
            "taskId": "PLAY-080",
            "direction": "south",
            "branch": "codex/citysim-world-art-south",
            "family": "industrial",
            "level": 4,
            "variant": 0,
            "logicalID": "industrial_l04_v0_south",
            "sourceKey": "industrial_l04/variant-0/south/source-v01",
            "sourceRoot": str(SOURCE_DIR.relative_to(REPOSITORY_ROOT)) + "/",
            "evidenceRoot": (
                "docs/production/evidence/PLAY-080/"
                "industrial-l04-south-source-v01/"
            ),
            "orientationTransform": "none",
            "fallbackSourceKey": None,
        },
        "lineage": {
            "publishedBaseline": contract["baselineCommit"],
            "cellContentCommit": head,
        },
        "authorities": {
            "contract010": authorities["artContract"],
            "contract021": {
                **authorities["governingContract"],
                "revision": 2,
            },
            "directionBridge": {
                "documentPath": bridge["acceptancePath"],
                "sourceCandidate": bridge["acceptedCandidateCommit"],
                "integratedProofCommit": bridge["integratedProofCommit"],
                "documentSha256": bridge["acceptanceSha256"],
                "mappingContractSha256": bridge["mappingContractSha256"],
                "coordinateSystem": "citysim_source_pixels_v1",
            },
            "appearanceLock": appearance,
            "lockedMaterialMapping": material,
            "sourceProductionProfile": profile,
            "nonAliasInput": {
                **authorities["nonAliasInput"],
                "forbiddenDecodedRgbaSha256Count": 44,
                "forbiddenSetSha256": (
                    "265c564785a5fa4ce14fbd04898ef04aaed883e2ca56f6a0660a9937464926ea"
                ),
            },
            "nonAliasLoader": authorities["nonAliasLoader"],
            "semanticValidator": authorities["semanticValidator"],
            "canonicalDecoder": authorities["canonicalDecoder"],
        },
        "inputs": {
            "prelaunchHandoff": artifact(
                contract["outputInventory"]["parallelZeroPixelHandoff"]
            ),
            "frozenInputManifest": manifest_artifact,
            "runnerContract": artifact(
                str(DEFAULT_CONTRACT.relative_to(REPOSITORY_ROOT))
            ),
            "outputRoot": plan["baseOutputRoot"],
        },
        "launch": {
            "guardReceipt": guard_artifact,
            "result": "PASS",
            "authorizedProcesses": ["A", "B", "C"],
            "isolatedOutputRoots": plan["isolatedOutputRoots"],
            "allOutputRootsDistinct": True,
            "outputRootIsolationReceipt": roots_artifact,
        },
        "completion": None,
        "candidateReadyForIndependentReview": False,
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
    }


def prepare(contract_path: Path) -> tuple[dict[str, bytes], dict[str, Any]]:
    contract = load_json(contract_path)
    run_production.validate_contract_shape(contract)
    if contract.get("state") != "appearance_lock_bound":
        raise LaunchBindingRejected(
            "RUNNER_NOT_APPEARANCE_LOCK_BOUND", contract.get("state")
        )
    if git("branch", "--show-current") != "codex/citysim-world-art-south":
        raise LaunchBindingRejected("WRONG_BRANCH", git("branch", "--show-current"))
    if git("status", "--porcelain"):
        raise LaunchBindingRejected("WORKTREE_NOT_CLEAN", git("status", "--porcelain"))

    head = git("rev-parse", "HEAD")
    origin_master = git("rev-parse", "origin/master")
    require_ancestor(contract["baselineCommit"], head, "baseline:HEAD")
    require_ancestor(contract["baselineCommit"], origin_master, "baseline:origin/master")
    appearance = appearance_authority(contract, origin_master, head)
    material = committed_artifact(
        contract["lockedMaterialMapping"], "lockedMaterialMapping", origin_master, head
    )
    profile_record = committed_artifact(
        contract["sourceProductionProfile"],
        "sourceProductionProfile",
        origin_master,
        head,
    )
    committed_artifact(
        contract["postLockProductionAuthority"],
        "postLockProductionAuthority",
        origin_master,
        head,
    )
    run_production.require_lock(contract)
    run_production.require_coordinate_bridge(contract)
    plan = run_production.require_launch_plan(contract)
    validate_source_profile(
        profile_record, appearance, material, contract
    )

    occupied = [
        value
        for value in (
            *plan["isolatedOutputRoots"].values(),
            *plan["isolatedEvidenceRoots"].values(),
        )
        if repo_path(value).exists()
    ]
    if occupied:
        raise LaunchBindingRejected("IMMUTABLE_ROOT_ALREADY_EXISTS", occupied)

    inventory = contract["outputInventory"]
    output_paths = {
        "manifest": inventory["frozenInputManifest"],
        "guard": inventory["launchGuardReceipt"],
        "roots": inventory["outputRootIsolationReceipt"],
        "packet": inventory["launchBoundHandoff"],
    }
    existing = [path for path in output_paths.values() if repo_path(path).exists()]
    if existing:
        raise LaunchBindingRejected("LAUNCH_BUNDLE_ALREADY_EXISTS", existing)

    manifest = {
        "schema": "citysim.play-080.future-source-frozen-inputs.v1",
        "taskId": "PLAY-080",
        "direction": "south",
        "contentCommit": head,
        "runnerContract": artifact(str(contract_path.relative_to(REPOSITORY_ROOT))),
        "acceptedPredesign": contract["acceptedPredesign"],
        "coordinateBridge": contract["coordinateBridge"],
        "authorities": {
            "appearanceLock": appearance,
            "lockedMaterialMapping": material,
            "sourceProductionProfile": profile_record,
            "postLockProductionAuthority": contract["postLockProductionAuthority"],
            "sourceStageSchema": contract["authorities"]["sourceStageHandoffSchema"],
        },
        "sourceReady": False,
        "productionSelected": False,
    }
    roots_receipt = {
        "schema": "citysim.play-080.output-root-isolation.v1",
        "taskId": "PLAY-080",
        "direction": "south",
        "authorizedProcesses": ["A", "B", "C"],
        "isolatedOutputRoots": plan["isolatedOutputRoots"],
        "isolatedEvidenceRoots": plan["isolatedEvidenceRoots"],
        "allRootsDistinct": True,
        "allRootsAbsent": True,
        "noOverwrite": True,
        "result": "PASS",
    }
    guard = {
        "schema": "citysim.play-080.future-source-launch-guard.v1",
        "taskId": "PLAY-080",
        "direction": "south",
        "result": "PASS",
        "head": head,
        "originMaster": origin_master,
        "authorityCommitsOnOriginMaster": True,
        "authorityCommitsInHead": True,
        "sourceProductionProfile": profile_record,
        "appearanceLock": appearance,
        "lockedMaterialMapping": material,
        "postLockProductionAuthority": contract["postLockProductionAuthority"],
        "authorizedProcesses": ["A", "B", "C"],
        "maximumConcurrentDccProcesses": 2,
        "blenderProcessLaunches": 0,
        "blenderRenderApiCalls": 0,
        "pixelFiles": 0,
        "sourceReady": False,
        "productionSelected": False,
    }
    contents = {
        "manifest": encode_json(manifest),
        "guard": encode_json(guard),
        "roots": encode_json(roots_receipt),
    }
    packet = build_packet(
        contract,
        head,
        appearance,
        material,
        profile_record,
        artifact(output_paths["manifest"], contents["manifest"]),
        artifact(output_paths["guard"], contents["guard"]),
        artifact(output_paths["roots"], contents["roots"]),
    )
    schema_path = repo_path(SCHEMA_PATH)
    if sha256(schema_path) != SCHEMA_SHA256:
        raise LaunchBindingRejected("SOURCE_STAGE_SCHEMA_DRIFT", sha256(schema_path))
    schema = load_json(schema_path)
    Draft202012Validator.check_schema(schema)
    errors = list(Draft202012Validator(schema).iter_errors(packet))
    if errors:
        raise LaunchBindingRejected(
            "LAUNCH_PACKET_SCHEMA_REJECTION", errors[0].message
        )
    contents["packet"] = encode_json(packet)
    return {
        output_paths[key]: contents[key] for key in ("manifest", "guard", "roots", "packet")
    }, packet


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--contract", type=Path, default=DEFAULT_CONTRACT)
    args = parser.parse_args()
    try:
        outputs, packet = prepare(args.contract.resolve())
    except (LaunchBindingRejected, run_production.GuardRejected, OSError, ValueError) as error:
        code = getattr(error, "code", type(error).__name__)
        detail = getattr(error, "detail", getattr(error, "details", str(error)))
        print(json.dumps({"result": "REJECTED", "code": code, "detail": detail}, sort_keys=True))
        return 2
    for display_path, content in outputs.items():
        write_once(repo_path(display_path), content)
    print(
        json.dumps(
            {
                "result": "PASS",
                "stage": packet["stage"],
                "outputs": sorted(outputs),
                "blenderProcessLaunches": 0,
                "pixelFiles": 0,
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
