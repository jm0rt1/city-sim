#!/usr/bin/env python3
"""Fail-closed validator for the PLAY-083 lifecycle binding candidate."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable


REQUEST_PATH = Path(
    "docs/production/evidence/PLAY-075/"
    "industrial-l4-family-preregistration-v1/"
    "production-quality-rubric-v2/"
    "UPSTREAM-LIFECYCLE-SAVE-REQUEST.json"
)
REQUEST_SHA256 = "73842570ee5d10e83ef3ec59b301dd9998959bd07e9d3d64e4d9d49c678bf51b"
FIXTURE_ROOT = Path(
    "Native/CitySimNative/Tests/CitySimNativeTests/Fixtures/VisibleCityStates"
)
MANIFEST_PATH = FIXTURE_ROOT / "visible-city-states-manifest-v3.json"
MANIFEST_SHA256 = "9eed6405adc84b8bdf025bb2ac1365b327c8659bdbf0384bc6f172d6c9a2aace"
MANIFEST_GIT_BLOB = "40df8ccd154677f67d3141b33372ba406fc6346f"
BASE_AUTHORITY = "c00f8295973d527c597c333769b7c4ef7d3acca5"

EXPECTED = {
    "early": {
        "semanticMapping": "early_to_active",
        "manifestID": "industrial-active-district-v3",
        "manifestLifecycle": "active",
        "file": "visible-city-industrial-active-district-v3.json",
        "gitBlob": "af685a8ac6479f97ab12e342a75a726250e58497",
        "fileSHA256": "48a45a4f3901eee09fca2bcf10315381e421dbc605ffa050e13fbee5dc17fdc3",
        "expectedStateDigest": "1a47eeb6c6a20b742c121f4b8f1e39a8682df54a8ede1528e8715f99885126ca",
        "spatialDigest": "e2646bba29246376e3e3a2a5c735cd3a7b1ee718cd29fe850cc67d25e0bf7fe7",
        "diagnosticDigest": "62c0966c63078521177fe9eb6011c0396d2ec6ee38b571cd1d48ba46c294a63e",
        "activityDigest": "de199fb7d9f0e0e03cefd31e7873c0f7f69ba07b53ea6bcccdaf5783e6bbe6de",
        "tick": 68,
        "focus": {"x": 5, "y": 8},
        "strategyPhase": "opportunity",
        "secondActPhase": None,
        "resolution": None,
        "townCharterAwarded": False,
    },
    "recovered": {
        "semanticMapping": "recovered_to_recovering",
        "manifestID": "industrial-recovering-district-v3",
        "manifestLifecycle": "recovering",
        "file": "visible-city-industrial-recovering-district-v3.json",
        "gitBlob": "9b408b2d01763b5a986287e968f4732e67c2a420",
        "fileSHA256": "5a278e43873f364c986545a856eec6a8ba4315b712b843028dcc5d8e602720f4",
        "expectedStateDigest": "a1525b36f38fc0fb2dfbd042d8fd8748088cbc57f9f3f1549be1e3f88653ad7d",
        "spatialDigest": "de91f0b9d99398508b4eb4c5e84ac1dc1e8abb0cc401ff7b64bf748bbf3e816c",
        "diagnosticDigest": "befd4256642557eb7d266e5f0412affeb8a6b608410258f0f943e4cd8ad84d25",
        "activityDigest": "c4aef758a8dc4d22fba33e234a7208a0567ee1e04790c7669566e609d45b6fee",
        "tick": 992,
        "focus": {"x": 4, "y": 8},
        "strategyPhase": "completed",
        "secondActPhase": "qualification",
        "resolution": "industrialUtilityExpansion",
        "townCharterAwarded": True,
    },
}

REQUIRED_TRUE_PROOFS = {
    "committedBytesMatchGeneration",
    "corruptPrimaryBackupRecovery",
    "digestReproduction",
    "historicalBytesPreserved",
    "manifestHashAndCount",
    "primaryLoad",
    "recursiveByteIdentity",
    "replayExact",
    "saveRoundTripByteExact",
    "snapshotImmutable",
    "storeLoadPausedAndUndoCleared",
    "twoIndependentOutputRoots",
    "undoExact",
}

ALLOWED_CANDIDATE_PATHS = {
    "Native/CitySimNative/Tests/CitySimNativeTests/PLAY083LifecycleBindingTests.swift",
    "docs/production/completed/PLAY-083.simulation-platform.md",
}
ALLOWED_CANDIDATE_PREFIX = "docs/production/evidence/PLAY-083/"


@dataclass
class ValidationFailure(Exception):
    code: str
    detail: str

    def __str__(self) -> str:
        return f"{self.code}: {self.detail}"


def fail(code: str, detail: str) -> None:
    raise ValidationFailure(code, detail)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git_blob(data: bytes) -> str:
    header = f"blob {len(data)}\0".encode()
    return hashlib.sha1(header + data).hexdigest()


def require(condition: bool, code: str, detail: str) -> None:
    if not condition:
        fail(code, detail)


def git(repo: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=repo,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        fail("unpublished_or_uncommitted_save", result.stderr.strip() or "git failed")
    return result.stdout.strip()


def tile_at(state: dict[str, Any], coordinate: dict[str, int]) -> dict[str, Any]:
    for tile in state["tiles"]:
        if tile["coordinate"] == coordinate:
            return tile
    fail("focus_coordinate_or_kind_mismatch", f"missing tile {coordinate}")


def validate_packet(packet: dict[str, Any], repo: Path, *, check_git: bool = True) -> dict[str, Any]:
    require(
        packet.get("documentType") == "PLAY-083_LIFECYCLE_BINDING_CANDIDATE",
        "lifecycle_semantics_mismatch",
        "unexpected document type",
    )
    require(
        packet.get("status") == "CANDIDATE_FOR_INTEGRATION_REVIEW",
        "app_launch_capture_score_or_acceptance_claim",
        "candidate must remain review-only",
    )

    request = packet.get("request", {})
    require(
        request.get("path") == REQUEST_PATH.as_posix()
        and request.get("sha256") == REQUEST_SHA256,
        "missing_or_stale_manifest_authority",
        "request identity mismatch",
    )
    request_bytes = (repo / REQUEST_PATH).read_bytes()
    require(
        sha256(request_bytes) == REQUEST_SHA256,
        "missing_or_stale_manifest_authority",
        "request bytes drifted",
    )

    manifest_bytes = (repo / MANIFEST_PATH).read_bytes()
    manifest = json.loads(manifest_bytes)
    packet_manifest = packet.get("manifest", {})
    require(
        packet_manifest.get("path") == MANIFEST_PATH.as_posix()
        and packet_manifest.get("sha256") == MANIFEST_SHA256
        and packet_manifest.get("gitBlob") == MANIFEST_GIT_BLOB,
        "missing_or_stale_manifest_authority",
        "packet manifest authority mismatch",
    )
    require(
        sha256(manifest_bytes) == MANIFEST_SHA256
        and git_blob(manifest_bytes) == MANIFEST_GIT_BLOB,
        "missing_or_stale_manifest_authority",
        "committed manifest bytes drifted",
    )
    require(
        manifest.get("schemaVersion") == 1
        and manifest.get("fingerprintVersion") == 1
        and manifest.get("seed") == 42,
        "schema_or_fingerprint_version_drift",
        "manifest version or seed drift",
    )
    for field in (
        "authorityCommit",
        "fixtureSet",
        "sourceStoryManifestSHA256",
        "schemaVersion",
        "fingerprintVersion",
        "seed",
    ):
        require(
            packet_manifest.get(field) == manifest.get(field),
            "missing_or_stale_manifest_authority",
            f"manifest field mismatch: {field}",
        )

    mappings = packet.get("mappings")
    require(isinstance(mappings, list), "missing_early_binding", "mappings missing")
    rubric_states = [item.get("rubricState") for item in mappings]
    require("early" in rubric_states, "missing_early_binding", "early absent")
    require("recovered" in rubric_states, "missing_recovered_binding", "recovered absent")
    require(
        len(mappings) == 2,
        "one_state_only",
        f"expected exactly two mappings, received {len(mappings)}",
    )
    require(
        len({item.get("manifestID") for item in mappings}) == 2
        and len({item.get("path") for item in mappings}) == 2,
        "duplicate_manifest_id_or_path",
        "duplicate mapping identity",
    )

    manifest_entries = {entry["id"]: entry for entry in manifest["fixtures"]}
    for item in mappings:
        rubric_state = item["rubricState"]
        expected = EXPECTED[rubric_state]
        expected_path = (FIXTURE_ROOT / expected["file"]).as_posix()
        require(
            item.get("path") == expected_path
            and Path(item["path"]).is_relative_to(FIXTURE_ROOT),
            "path_outside_authorized_fixture_root",
            f"{rubric_state} path escaped or changed",
        )
        require(
            item.get("semanticMapping") == expected["semanticMapping"],
            (
                "active_relabeled_early_without_integration_mapping"
                if rubric_state == "early"
                else "recovering_relabeled_recovered_without_integration_mapping"
            ),
            f"{rubric_state} semantic mapping mismatch",
        )
        require(
            item.get("manifestID") == expected["manifestID"]
            and item.get("manifestLifecycle") == expected["manifestLifecycle"],
            "lifecycle_semantics_mismatch",
            f"{rubric_state} lifecycle mismatch",
        )
        entry = manifest_entries.get(expected["manifestID"])
        require(entry is not None, "missing_or_stale_manifest_authority", "entry absent")
        save_bytes = (repo / item["path"]).read_bytes()
        require(
            item.get("fileSHA256") == expected["fileSHA256"]
            and sha256(save_bytes) == expected["fileSHA256"]
            and item.get("gitBlob") == expected["gitBlob"]
            and git_blob(save_bytes) == expected["gitBlob"]
            and item.get("byteCount") == len(save_bytes),
            "null_or_mismatched_hash_or_digest",
            f"{rubric_state} file identity mismatch",
        )
        for field in (
            "expectedStateDigest",
            "spatialDigest",
            "diagnosticDigest",
            "activityDigest",
        ):
            require(
                item.get(field) == expected[field] == entry.get(field),
                "null_or_mismatched_hash_or_digest",
                f"{rubric_state} {field} mismatch",
            )
        require(
            entry.get("file") == expected["file"]
            and entry.get("fileSHA256") == expected["fileSHA256"]
            and entry.get("byteCount") == len(save_bytes),
            "manifest_hash_and_count",
            f"{rubric_state} manifest file identity mismatch",
        )

        envelope = json.loads(save_bytes)
        require(
            envelope.get("schemaVersion") == 1
            and envelope.get("fingerprintVersion") == 1
            and item.get("schemaVersion") == 1
            and item.get("fingerprintVersion") == 1,
            "schema_or_fingerprint_version_drift",
            f"{rubric_state} save version mismatch",
        )
        require(
            envelope.get("digest") == expected["expectedStateDigest"],
            "null_or_mismatched_hash_or_digest",
            f"{rubric_state} envelope digest mismatch",
        )
        state = envelope["state"]
        progression = state["progression"]
        strategy = progression["strategy"]
        second_act = progression.get("secondAct")
        require(
            state.get("tick") == expected["tick"]
            and state.get("status") == "playing"
            and item.get("tick") == expected["tick"]
            and item.get("status") == "playing"
            and strategy.get("committedStrategy") == "industrialExpansion"
            and strategy.get("currentPhase") == expected["strategyPhase"]
            and item.get("strategy") == "industrialExpansion"
            and item.get("strategyDistrictKind") == "industrial"
            and item.get("strategyPhase") == expected["strategyPhase"]
            and progression.get("townCharterAwarded") is expected["townCharterAwarded"]
            and (second_act or {}).get("phase") == expected["secondActPhase"]
            and item.get("secondActPhase") == expected["secondActPhase"]
            and strategy.get("recoveryResolution") == expected["resolution"]
            and item.get("resolution") == expected["resolution"],
            "status_or_progression_mismatch",
            f"{rubric_state} state or progression mismatch",
        )
        focus = tile_at(state, expected["focus"])
        require(
            item.get("focusCoordinate") == expected["focus"]
            and item.get("focusKind") == "industrial"
            and focus.get("kind") == "industrial"
            and focus.get("constructionProgress") == 1
            and focus.get("occupancy", 0) > 0,
            "focus_coordinate_or_kind_mismatch",
            f"{rubric_state} focus mismatch",
        )
        if rubric_state == "early":
            require(
                second_act is None and strategy.get("recoveryResolution") is None,
                "lifecycle_semantics_mismatch",
                "early includes pressure or recovery state",
            )
        else:
            industrial = [tile for tile in state["tiles"] if tile["kind"] == "industrial"]
            require(
                focus.get("condition") == 0.64
                and focus.get("level") == 3
                and not [tile for tile in industrial if tile["condition"] < 0.4]
                and len(
                    [
                        tile
                        for tile in industrial
                        if 0.4 <= tile["condition"] < 0.75
                    ]
                )
                == 1
                and second_act.get("regionalCapitalAwarded") is False,
                "lifecycle_semantics_mismatch",
                "recovered residual-recovery semantics mismatch",
            )
        require(
            isinstance(item.get("replayProvenance"), str)
            and item["replayProvenance"],
            "replay_relationship_mismatch",
            f"{rubric_state} replay provenance missing",
        )

    proofs = packet.get("proofs", {})
    for proof in REQUIRED_TRUE_PROOFS:
        code = {
            "recursiveByteIdentity": "two_run_materialization_difference",
            "twoIndependentOutputRoots": "two_run_materialization_difference",
            "saveRoundTripByteExact": "save_round_trip_byte_difference",
            "replayExact": "replay_relationship_mismatch",
            "historicalBytesPreserved": "historical_fixture_byte_drift",
        }.get(proof, "lifecycle_semantics_mismatch")
        require(proofs.get(proof) is True, code, f"proof failed: {proof}")
    require(
        proofs.get("fingerprintRepeatCountPerState") == 5,
        "null_or_mismatched_hash_or_digest",
        "five fingerprints per state not proven",
    )

    qa = packet.get("qa", {})
    require(
        qa.get("mappingAuthorityPublished") is False
        and qa.get("rehearsalStatus") == "BLOCKED",
        "app_launch_capture_score_or_acceptance_claim",
        "worker must keep QA blocked",
    )
    scope = packet.get("scope", {})
    require(
        scope.get("fixtureMutations") == 0
        and scope.get("manifestMutations") == 0,
        "existing_fixture_rename_overwrite_or_rewrite",
        "fixture or manifest mutation claimed",
    )
    require(
        scope.get("productMutations") == 0,
        "product_save_schema_gameplay_renderer_ui_or_art_change_without_separate_authority",
        "product mutation claimed",
    )
    require(
        scope.get("scores") == 0 and scope.get("acceptanceDecisions") == 0,
        "candidate_specific_coaching_or_measurement",
        "coaching, score, or acceptance claimed",
    )
    require(
        scope.get("appLaunches") == 0 and scope.get("captures") == 0,
        "app_launch_capture_score_or_acceptance_claim",
        "app launch or capture claimed",
    )
    require(
        packet.get("failClosedNegativeCount") == 22,
        "lifecycle_semantics_mismatch",
        "negative gate count mismatch",
    )

    authority = packet.get("authority", {})
    candidate_commit = authority.get("candidateCommit", "")
    require(
        authority.get("basePublishedMaster") == BASE_AUTHORITY
        and authority.get("branch") == "codex/citysim-simulation-platform"
        and authority.get("claimPath")
        == "docs/production/claims/PLAY-083.simulation-platform.md"
        and len(candidate_commit) == 40
        and candidate_commit != "0" * 40,
        "unpublished_or_uncommitted_save",
        "candidate authority incomplete",
    )
    if check_git:
        require(
            git(repo, "cat-file", "-t", candidate_commit) == "commit",
            "unpublished_or_uncommitted_save",
            "candidate commit missing",
        )
        changed = set(
            filter(
                None,
                git(repo, "diff", "--name-only", BASE_AUTHORITY, candidate_commit).splitlines(),
            )
        )
        unexpected = sorted(
            path
            for path in changed
            if path not in ALLOWED_CANDIDATE_PATHS
            and not path.startswith(ALLOWED_CANDIDATE_PREFIX)
        )
        require(
            not unexpected,
            "product_save_schema_gameplay_renderer_ui_or_art_change_without_separate_authority",
            f"candidate changed unauthorized paths: {unexpected}",
        )

    return {
        "result": "PASS_CANDIDATE_FOR_INTEGRATION_REVIEW",
        "mappingsValidated": ["early_to_active", "recovered_to_recovering"],
        "qaRehearsal": "BLOCKED",
    }


def set_mapping(packet: dict[str, Any], rubric_state: str, field: str, value: Any) -> None:
    mapping = next(item for item in packet["mappings"] if item["rubricState"] == rubric_state)
    mapping[field] = value


def remove_mapping(packet: dict[str, Any], rubric_state: str) -> None:
    packet["mappings"] = [
        item for item in packet["mappings"] if item["rubricState"] != rubric_state
    ]


def negative_cases() -> list[tuple[str, Callable[[dict[str, Any]], None]]]:
    return [
        ("missing_early_binding", lambda p: remove_mapping(p, "early")),
        ("missing_recovered_binding", lambda p: remove_mapping(p, "recovered")),
        ("one_state_only", lambda p: p.__setitem__("mappings", p["mappings"][:1])),
        (
            "active_relabeled_early_without_integration_mapping",
            lambda p: set_mapping(p, "early", "semanticMapping", "early"),
        ),
        (
            "recovering_relabeled_recovered_without_integration_mapping",
            lambda p: set_mapping(p, "recovered", "semanticMapping", "recovered"),
        ),
        (
            "lifecycle_semantics_mismatch",
            lambda p: set_mapping(p, "recovered", "manifestLifecycle", "active"),
        ),
        (
            "replay_relationship_mismatch",
            lambda p: p["proofs"].__setitem__("replayExact", False),
        ),
        (
            "status_or_progression_mismatch",
            lambda p: set_mapping(p, "early", "strategyPhase", "pressure"),
        ),
        (
            "focus_coordinate_or_kind_mismatch",
            lambda p: set_mapping(p, "early", "focusKind", "commercial"),
        ),
        (
            "path_outside_authorized_fixture_root",
            lambda p: set_mapping(p, "early", "path", "../outside.json"),
        ),
        (
            "unpublished_or_uncommitted_save",
            lambda p: p["authority"].__setitem__("candidateCommit", "0" * 40),
        ),
        (
            "missing_or_stale_manifest_authority",
            lambda p: p["manifest"].__setitem__("sha256", "0" * 64),
        ),
        (
            "null_or_mismatched_hash_or_digest",
            lambda p: set_mapping(p, "early", "expectedStateDigest", None),
        ),
        (
            "duplicate_manifest_id_or_path",
            lambda p: set_mapping(
                p, "recovered", "manifestID", EXPECTED["early"]["manifestID"]
            ),
        ),
        (
            "two_run_materialization_difference",
            lambda p: p["proofs"].__setitem__("recursiveByteIdentity", False),
        ),
        (
            "save_round_trip_byte_difference",
            lambda p: p["proofs"].__setitem__("saveRoundTripByteExact", False),
        ),
        (
            "schema_or_fingerprint_version_drift",
            lambda p: set_mapping(p, "early", "schemaVersion", 2),
        ),
        (
            "historical_fixture_byte_drift",
            lambda p: p["proofs"].__setitem__("historicalBytesPreserved", False),
        ),
        (
            "existing_fixture_rename_overwrite_or_rewrite",
            lambda p: p["scope"].__setitem__("fixtureMutations", 1),
        ),
        (
            "product_save_schema_gameplay_renderer_ui_or_art_change_without_separate_authority",
            lambda p: p["scope"].__setitem__("productMutations", 1),
        ),
        (
            "candidate_specific_coaching_or_measurement",
            lambda p: p["scope"].__setitem__("scores", 1),
        ),
        (
            "app_launch_capture_score_or_acceptance_claim",
            lambda p: p["scope"].__setitem__("appLaunches", 1),
        ),
    ]


def run_negative_self_test(packet: dict[str, Any], repo: Path) -> dict[str, Any]:
    results = []
    for expected_code, mutate in negative_cases():
        candidate = copy.deepcopy(packet)
        mutate(candidate)
        try:
            validate_packet(candidate, repo, check_git=False)
        except ValidationFailure as error:
            require(
                error.code == expected_code
                or expected_code == "one_state_only"
                and error.code in {"missing_early_binding", "missing_recovered_binding"},
                "negative_gate_wrong_failure",
                f"{expected_code} produced {error.code}",
            )
            results.append({"id": expected_code, "result": "PASS_FAIL_CLOSED"})
        else:
            fail("negative_gate_did_not_fail", expected_code)
    return {
        "documentType": "PLAY-083_FAIL_CLOSED_NEGATIVE_VALIDATION",
        "negativeCount": len(results),
        "result": "PASS_22_OF_22",
        "tests": results,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--packet", type=Path, required=True)
    parser.add_argument("--self-test-negatives", action="store_true")
    args = parser.parse_args()

    repo = args.repo.resolve()
    packet = json.loads(args.packet.read_bytes())
    try:
        positive = validate_packet(packet, repo)
        output: dict[str, Any] = {"positive": positive}
        if args.self_test_negatives:
            output["negatives"] = run_negative_self_test(packet, repo)
        print(json.dumps(output, indent=2, sort_keys=True))
        return 0
    except (OSError, KeyError, TypeError, ValueError, ValidationFailure) as error:
        print(f"PLAY083_VALIDATION_FAIL {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
