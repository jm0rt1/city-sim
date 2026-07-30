#!/usr/bin/env python3
"""Generate the read-only PLAY-088 phase-A persistence input packet."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any


AUTHORITY = "448fd45c2fb07e7c6efdd4ac19764cdd04ce6cda"
CLAIM_PATH = Path("docs/production/claims/PLAY-088.simulation-platform.md")
CLAIM_SHA256 = "516234a4496b6c643557397d03e4feef3e375355965d2e50de7fbc44ab50a282"
CONTRACT_PATH = Path(
    "docs/production/decisions/CONTRACT-022-durable-storm-recovery-ownership.md"
)
FIXTURE_ROOT = Path("Native/CitySimNative/Tests/CitySimNativeTests/Fixtures")

SOURCE_INPUTS = {
    "authoritativeState": Path(
        "Native/CitySimNative/Sources/CitySimNative/Models/CityGameState.swift"
    ),
    "simulationAndReplay": Path(
        "Native/CitySimNative/Sources/CitySimNative/Services/CitySimulation.swift"
    ),
    "typedReplayCommands": Path(
        "Native/CitySimNative/Sources/CitySimNative/Services/CitySimulationCommand.swift"
    ),
    "canonicalFingerprint": Path(
        "Native/CitySimNative/Sources/CitySimNative/Services/CityStateFingerprint.swift"
    ),
    "savePrimaryBackup": Path(
        "Native/CitySimNative/Sources/CitySimNative/Services/SaveGameService.swift"
    ),
    "immutableSnapshot": Path(
        "Native/CitySimNative/Sources/CitySimNative/Models/CityPresentationSnapshot.swift"
    ),
    "storeLoadAndUndo": Path(
        "Native/CitySimNative/Sources/CitySimNative/Stores/CityGameStore.swift"
    ),
    "sessionPlatformTests": Path(
        "Native/CitySimNative/Tests/CitySimNativeTests/SessionPlatformTests.swift"
    ),
    "simulationTests": Path(
        "Native/CitySimNative/Tests/CitySimNativeTests/CitySimulationTests.swift"
    ),
    "storyFixtureTests": Path(
        "Native/CitySimNative/Tests/CitySimNativeTests/"
        "ProductionStoryStateFixtureTests.swift"
    ),
    "storyFixtureSupport": Path(
        "Native/CitySimNative/Tests/CitySimNativeTests/"
        "ProductionStoryStateFixtureSupport.swift"
    ),
    "visibleFixtureTests": Path(
        "Native/CitySimNative/Tests/CitySimNativeTests/VisibleCityStateFixtureTests.swift"
    ),
    "visibleFixtureSupport": Path(
        "Native/CitySimNative/Tests/CitySimNativeTests/VisibleCityStateFixtureSupport.swift"
    ),
    "strategyResolutionTests": Path(
        "Native/CitySimNative/Tests/CitySimNativeTests/"
        "StrategyResolutionPlatformTests.swift"
    ),
    "terminalVictoryTests": Path(
        "Native/CitySimNative/Tests/CitySimNativeTests/TerminalVictoryPlatformTests.swift"
    ),
    "spatialSnapshotTests": Path(
        "Native/CitySimNative/Tests/CitySimNativeTests/SpatialConsequenceTests.swift"
    ),
}

NEW_CITY_INPUTS = [
    {
        "id": "new-city-seed-42-explicit-progression",
        "seed": 42,
        "canonicalByteCount": 63107,
        "canonicalSHA256": "ee95ebc98d8314e2ae2661baa03bc11809a70811cec1fdfb5633930ee78186d3",
        "fingerprintVersion": 1,
        "progression": "CityProgressionState()",
        "sourceAssertion": (
            "SessionPlatformTests.testVersionOneFingerprintFixturesAreFrozen"
        ),
    },
    {
        "id": "new-city-seed-42-nil-progression-control",
        "seed": 42,
        "canonicalByteCount": 63032,
        "canonicalSHA256": "bba31f738c9b3b4d4e91d22714d151520736cf3aa48fabb67f15e0b2d9bbceb7",
        "fingerprintVersion": 1,
        "progression": None,
        "sourceAssertion": (
            "SessionPlatformTests.testVersionOneFingerprintFixturesAreFrozen"
        ),
    },
]


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git_blob(data: bytes) -> str:
    header = f"blob {len(data)}\0".encode()
    return hashlib.sha1(header + data).hexdigest()


def authority_is_ancestor(repo: Path) -> bool:
    return subprocess.run(
        ["git", "merge-base", "--is-ancestor", AUTHORITY, "HEAD"],
        cwd=repo,
        check=False,
    ).returncode == 0


def file_record(repo: Path, path: Path) -> dict[str, Any]:
    data = (repo / path).read_bytes()
    return {
        "path": path.as_posix(),
        "byteCount": len(data),
        "sha256": sha256(data),
        "gitBlob": git_blob(data),
    }


def fixture_family(relative: Path) -> tuple[str, int | None]:
    name = relative.name
    version_match = re.search(r"-v(\d+)\.json$", name)
    version = int(version_match.group(1)) if version_match else None
    if relative.parts[0] == "StoryStates":
        return "storyStates", version
    if relative.parts[0] == "VisibleCityStates":
        return "visibleCityStates", version
    if name.startswith("strategy-legacy-"):
        return "authenticLegacySave", version
    return "fixtureManifest", version


def fixture_record(repo: Path, path: Path) -> dict[str, Any]:
    record = file_record(repo, path)
    relative = path.relative_to(FIXTURE_ROOT)
    family, corpus_version = fixture_family(relative)
    payload = json.loads((repo / path).read_text())
    record.update(
        {
            "relativeFixturePath": relative.as_posix(),
            "family": family,
            "corpusVersion": corpus_version,
            "schemaVersion": payload.get(
                "schemaVersion",
                0 if relative.name == "strategy-legacy-schema0-v1.json" else None,
            ),
            "fingerprintVersion": payload.get("fingerprintVersion"),
            "stateDigest": payload.get("digest"),
            "fixtureCount": (
                len(payload.get("fixtures", []))
                if isinstance(payload.get("fixtures"), list)
                else None
            ),
        }
    )
    return record


def validate_manifests(repo: Path) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    manifests = [
        FIXTURE_ROOT / "manifest.json",
        *sorted((repo / FIXTURE_ROOT / "StoryStates").glob("*manifest*.json")),
        *sorted((repo / FIXTURE_ROOT / "VisibleCityStates").glob("*manifest*.json")),
    ]
    normalized = [
        path if not path.is_absolute() else path.relative_to(repo) for path in manifests
    ]
    for manifest_path in normalized:
        payload = json.loads((repo / manifest_path).read_text())
        base = manifest_path.parent
        entries = payload["fixtures"]
        for entry in entries:
            fixture_path = base / entry["file"]
            data = (repo / fixture_path).read_bytes()
            actual_file_sha = sha256(data)
            if actual_file_sha != entry["fileSHA256"]:
                raise SystemExit(
                    f"{manifest_path}: {entry['file']} SHA mismatch "
                    f"{actual_file_sha} != {entry['fileSHA256']}"
                )
            fixture_payload = json.loads(data)
            state_digest = (
                fixture_payload.get("digest")
                if isinstance(fixture_payload, dict)
                else None
            )
            if (
                state_digest is not None
                and state_digest != entry["expectedStateDigest"]
            ):
                raise SystemExit(
                    f"{manifest_path}: {entry['file']} digest mismatch "
                    f"{state_digest} != {entry['expectedStateDigest']}"
                )
        results.append(
            {
                "path": manifest_path.as_posix(),
                "fixtureCount": len(entries),
                "result": "PASS_ALL_ADVERTISED_BYTES_AND_DIGESTS",
            }
        )
    return results


def gate(
    gate_id: str,
    requirement: str,
    inputs: list[str],
    phase: str = "B",
) -> dict[str, Any]:
    return {
        "id": gate_id,
        "phase": phase,
        "requirement": requirement,
        "inputs": inputs,
        "status": "NOT_RUN",
        "onFailure": "REJECT_CANDIDATE_AND_STOP",
    }


def acceptance_matrix(source_hashes: dict[str, dict[str, Any]]) -> dict[str, Any]:
    gates = [
        gate(
            "authority.exact-integrated-revision2",
            "Integration binds one exact integrated PLAY-085 revision-2 product commit.",
            [CLAIM_PATH.as_posix(), "future Integration dispatch"],
        ),
        gate(
            "authority.allowed-product-diff",
            "Candidate product changes are limited to CityGameState.swift and CitySimulation.swift.",
            [
                SOURCE_INPUTS["authoritativeState"].as_posix(),
                SOURCE_INPUTS["simulationAndReplay"].as_posix(),
            ],
        ),
        gate(
            "contract.internal-types-only",
            "Storm recovery values are internal Codable, Equatable, Sendable values with only CONTRACT-022 fields.",
            [SOURCE_INPUTS["authoritativeState"].as_posix(), CONTRACT_PATH.as_posix()],
        ),
        gate(
            "compat.schema-1",
            "SaveGameEnvelope.currentSchemaVersion remains 1.",
            [SOURCE_INPUTS["savePrimaryBackup"].as_posix()],
        ),
        gate(
            "compat.fingerprint-v1",
            "CityStateFingerprint.currentVersion remains 1 and unknown versions still reject.",
            [SOURCE_INPUTS["canonicalFingerprint"].as_posix()],
        ),
        gate(
            "compat.new-city-bytes",
            "Seed-42 new-city canonical bytes remain 63107 bytes with SHA-256 ee95ebc9...86d3.",
            [SOURCE_INPUTS["authoritativeState"].as_posix()],
        ),
        gate(
            "compat.nil-control-bytes",
            "Nil-progression control remains 63032 bytes with SHA-256 bba31f73...ceb7.",
            [SOURCE_INPUTS["authoritativeState"].as_posix()],
        ),
        gate(
            "compat.legacy-missing-key",
            "Authentic schema-0 and schema-1 bytes decode missing stormRecovery as nil and re-encode canonically unchanged.",
            [
                f"{FIXTURE_ROOT}/strategy-legacy-schema0-v1.json",
                f"{FIXTURE_ROOT}/strategy-legacy-schema1-envelope-v1.json",
            ],
        ),
        gate(
            "compat.all-frozen-fixtures",
            "Every phase-A fixture byte/hash/digest and every manifest byte remains unchanged.",
            [FIXTURE_ROOT.as_posix(), "phase-a-current-inputs.json"],
        ),
        gate(
            "fingerprint.nil-omission",
            "Nil stormRecovery is omitted and produces no canonical-byte or v1 fingerprint drift.",
            [SOURCE_INPUTS["authoritativeState"].as_posix()],
        ),
        gate(
            "fingerprint.active-repeat",
            "An active ledger has one repeatable v1 fingerprint distinct from its nil predecessor.",
            [SOURCE_INPUTS["canonicalFingerprint"].as_posix()],
        ),
        gate(
            "fingerprint.recovered-repeat",
            "A recovered ledger has one repeatable v1 fingerprint distinct from active and nil states.",
            [SOURCE_INPUTS["canonicalFingerprint"].as_posix()],
        ),
        gate(
            "ledger.actual-clamped-delta",
            "Targets record only actual post-clamp Residential condition decrement.",
            [SOURCE_INPUTS["simulationAndReplay"].as_posix()],
        ),
        gate(
            "ledger.row-major-identity",
            "Target coordinates and remaining damage are exact, unique, and stable row-major.",
            [SOURCE_INPUTS["simulationAndReplay"].as_posix()],
        ),
        gate(
            "ledger.second-storm-merge",
            "A second damaging storm merges unresolved damage by coordinate and updates event identity.",
            [SOURCE_INPUTS["simulationAndReplay"].as_posix()],
        ),
        gate(
            "ledger.zero-target-zero-delta",
            "Zero-target and zero-delta storms create neither authority nor completion.",
            [SOURCE_INPUTS["simulationAndReplay"].as_posix()],
        ),
        gate(
            "repair.exact-ownership",
            "Repair changes only active ledger damage; pre-existing Residential, Commercial, and Industrial scars remain.",
            [SOURCE_INPUTS["simulationAndReplay"].as_posix()],
        ),
        gate(
            "repair.headroom-and-clamp",
            "Repair is bounded by daily rate, remaining ownership, recoverable deficit, and condition 1.0.",
            [SOURCE_INPUTS["simulationAndReplay"].as_posix()],
        ),
        gate(
            "repair.retired-target",
            "Demolished, non-Residential, or replacement targets retire without healing.",
            [SOURCE_INPUTS["simulationAndReplay"].as_posix()],
        ),
        gate(
            "repair.message-independent",
            "Dismissal and at least twelve newer messages cannot stop, restart, or complete recovery.",
            [SOURCE_INPUTS["simulationAndReplay"].as_posix()],
        ),
        gate(
            "repair.completion-once",
            "Recovered disposition and Storm Recovery Complete occur exactly once.",
            [SOURCE_INPUTS["simulationAndReplay"].as_posix()],
        ),
        gate(
            "save.active-primary",
            "Active ledger schema-1 save/load returns exact state and fingerprint from primary.",
            [SOURCE_INPUTS["savePrimaryBackup"].as_posix()],
        ),
        gate(
            "save.recovered-primary",
            "Recovered ledger schema-1 save/load returns exact state and fingerprint from primary.",
            [SOURCE_INPUTS["savePrimaryBackup"].as_posix()],
        ),
        gate(
            "save.active-backup",
            "Corrupt-primary recovery returns the exact active ledger from backup and preserves corrupt bytes.",
            [SOURCE_INPUTS["savePrimaryBackup"].as_posix()],
        ),
        gate(
            "save.recovered-backup",
            "Corrupt-primary recovery returns the exact recovered ledger from backup and preserves corrupt bytes.",
            [SOURCE_INPUTS["savePrimaryBackup"].as_posix()],
        ),
        gate(
            "replay.command-exact",
            "Same initial state, seed, commands, and tick groupings yield exact state, seed, ledger, and fingerprint.",
            [
                SOURCE_INPUTS["typedReplayCommands"].as_posix(),
                SOURCE_INPUTS["simulationAndReplay"].as_posix(),
            ],
        ),
        gate(
            "snapshot.immutable-active",
            "Active-ledger presentation and spatial snapshots retain copied state and exact fingerprint after source mutation.",
            [SOURCE_INPUTS["immutableSnapshot"].as_posix()],
        ),
        gate(
            "snapshot.immutable-recovered",
            "Recovered-ledger presentation and spatial snapshots retain copied state and exact fingerprint after source mutation.",
            [SOURCE_INPUTS["immutableSnapshot"].as_posix()],
        ),
        gate(
            "undo.exact-active",
            "One store mutation followed by Undo restores the exact active ledger state and fingerprint.",
            [SOURCE_INPUTS["storeLoadAndUndo"].as_posix()],
        ),
        gate(
            "undo.exact-recovered",
            "One store mutation followed by Undo restores the exact recovered ledger state and fingerprint.",
            [SOURCE_INPUTS["storeLoadAndUndo"].as_posix()],
        ),
        gate(
            "store.load-semantics",
            "Primary or backup load pauses simulation, clears Undo, and retains current recovery feedback.",
            [SOURCE_INPUTS["storeLoadAndUndo"].as_posix()],
        ),
        gate(
            "regression.storm-identity",
            "Existing storm schedule, title, seed advance, treasury, and happiness assertions remain green.",
            [SOURCE_INPUTS["simulationTests"].as_posix()],
        ),
        gate(
            "regression.strategy-progression",
            "Strategy, progression, terminal, four-route, story, visible, and spatial fixture gates remain green.",
            [
                SOURCE_INPUTS["strategyResolutionTests"].as_posix(),
                SOURCE_INPUTS["terminalVictoryTests"].as_posix(),
                SOURCE_INPUTS["storyFixtureTests"].as_posix(),
                SOURCE_INPUTS["visibleFixtureTests"].as_posix(),
                SOURCE_INPUTS["spatialSnapshotTests"].as_posix(),
            ],
        ),
        gate(
            "budgets.existing",
            "Existing simulation, fingerprint, snapshot, save, load, byte-size, and retained-sample budgets do not regress.",
            [SOURCE_INPUTS["sessionPlatformTests"].as_posix()],
        ),
    ]
    return {
        "documentType": "PLAY-088_FUTURE_PLAY085_ACCEPTANCE_MATRIX",
        "matrixVersion": 1,
        "authority": AUTHORITY,
        "contract": CONTRACT_PATH.as_posix(),
        "claim": {"path": CLAIM_PATH.as_posix(), "sha256": CLAIM_SHA256},
        "candidateBinding": {
            "integratedPLAY085Revision2Commit": None,
            "integrationAuthorityCommit": None,
            "status": "BLOCKED_PENDING_EXACT_INTEGRATION_BINDING",
        },
        "evaluationPolicy": {
            "default": "REJECT",
            "allGatesRequired": True,
            "zeroHashAccepted": False,
            "missingInputAccepted": False,
            "unexpectedPathAccepted": False,
            "goldenDriftWithoutSemanticProofAccepted": False,
            "workerMaySelfAccept": False,
        },
        "prohibitedChanges": [
            "save schema identifier",
            "fingerprint version",
            "SaveGameService",
            "package topology",
            "CityGameStore behavior",
            "renderer",
            "UI or input",
            "commands",
            "existing fixtures or manifests",
            "message capacity",
            "gameplay balance or cadence beyond CONTRACT-022",
        ],
        "sourceInputSHA256": {
            name: record["sha256"] for name, record in sorted(source_hashes.items())
        },
        "gateCount": len(gates),
        "gates": gates,
        "phaseBDisposition": "BLOCKED_NOT_EVALUATED_NOT_ACCEPTED",
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    args = parser.parse_args()

    repo = args.repo.resolve()
    output = args.output_root.resolve()
    if not authority_is_ancestor(repo):
        raise SystemExit(f"HEAD must contain phase-A authority {AUTHORITY}")
    claim_data = (repo / CLAIM_PATH).read_bytes()
    if sha256(claim_data) != CLAIM_SHA256:
        raise SystemExit("PLAY-088 claim SHA-256 mismatch")

    source_hashes = {
        name: file_record(repo, path) for name, path in sorted(SOURCE_INPUTS.items())
    }
    fixtures = [
        fixture_record(repo, path.relative_to(repo))
        for path in sorted((repo / FIXTURE_ROOT).rglob("*.json"))
    ]
    family_counts: dict[str, int] = {}
    for fixture in fixtures:
        family_counts[fixture["family"]] = family_counts.get(fixture["family"], 0) + 1

    inventory = {
        "documentType": "PLAY-088_PHASE_A_CURRENT_INPUTS",
        "packetVersion": 1,
        "authority": AUTHORITY,
        "branch": "codex/citysim-simulation-platform",
        "claim": {"path": CLAIM_PATH.as_posix(), "sha256": CLAIM_SHA256},
        "contract": file_record(repo, CONTRACT_PATH),
        "versions": {
            "saveSchema": 1,
            "fingerprint": 1,
            "canonicalEncoding": "JSONEncoder sortedKeys over complete CityGameState",
            "saveEnvelopeEncoding": "JSONEncoder prettyPrinted plus sortedKeys",
        },
        "newCityCanonicalInputs": NEW_CITY_INPUTS,
        "persistenceInputMap": {
            "authoritativeState": "CityGameState complete Codable value",
            "fingerprint": "SHA-256(canonical sorted-key CityGameState JSON)",
            "schema0Load": "bare CityGameState JSON",
            "schema1Load": "SaveGameEnvelope(schemaVersion,fingerprintVersion,state,digest)",
            "save": "validated candidate then atomic primary replacement",
            "backup": "last valid primary copied before replacement; corrupt bytes preserved",
            "replay": "CitySimulationCommand plus deterministic CitySimulation.step",
            "snapshot": "copied CityGameState plus fingerprint and derived spatial consequences",
            "undo": "bounded in-memory pre-construction CityGameState stack; load clears stack",
        },
        "sourceInputs": source_hashes,
        "fixtureRoot": FIXTURE_ROOT.as_posix(),
        "fixtureFileCount": len(fixtures),
        "fixtureFamilyCounts": family_counts,
        "manifestValidation": validate_manifests(repo),
        "fixtureFiles": fixtures,
        "mutation": {
            "product": False,
            "tests": False,
            "fixtures": False,
            "manifests": False,
            "schemaOrFingerprintVersion": False,
        },
    }
    matrix = acceptance_matrix(source_hashes)

    output.mkdir(parents=True, exist_ok=True)
    (output / "phase-a-current-inputs.json").write_text(
        json.dumps(inventory, indent=2, sort_keys=True) + "\n"
    )
    (output / "future-play085-acceptance-matrix.json").write_text(
        json.dumps(matrix, indent=2, sort_keys=True) + "\n"
    )


if __name__ == "__main__":
    main()
