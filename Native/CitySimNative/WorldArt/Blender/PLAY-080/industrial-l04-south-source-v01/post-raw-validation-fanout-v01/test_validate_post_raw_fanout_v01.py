#!/usr/bin/env python3
"""Tests for the PLAY-080 South zero-pixel post-raw fan-out model."""

from __future__ import annotations

import copy
import json
from pathlib import Path
import subprocess
import sys
import unittest

import validate_post_raw_fanout_v01 as validator


class PostRawFanoutV01Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.contract_path = validator.REPOSITORY_ROOT / validator.CONTRACT_PATH
        cls.payload = validator.load_json_bytes(
            cls.contract_path.read_bytes(), validator.CONTRACT_PATH
        )

    def candidate(self) -> dict:
        return copy.deepcopy(self.payload)

    def assert_rejected(
        self,
        expected_code: str,
        candidate: dict,
        *,
        root_probe=lambda _path: "missing",
    ) -> None:
        with self.assertRaises(validator.FanoutRejected) as raised:
            validator.validate_payload(
                candidate,
                root_probe=root_probe,
                check_environment=False,
            )
        self.assertEqual(expected_code, raised.exception.code)

    def test_positive_blocked_contract_and_environment(self) -> None:
        result = validator.validate_payload(self.payload)
        self.assertEqual(18, len(result["checkedRoots"]))
        self.assertEqual(
            "integration-authority-is-ancestor",
            result["environment"]["runtimeHeadPolicy"],
        )
        self.assertFalse(self.payload["gates"]["sourceReady"])
        self.assertFalse(self.payload["gates"]["consumersReleased"])
        self.assertTrue(all(value == 0 for value in self.payload["activity"].values()))

    def test_all_embedded_adversaries_fail_closed(self) -> None:
        results = validator.run_adversaries(self.payload)
        self.assertEqual(16, len(results))
        self.assertTrue(
            all(case["result"] == "PASS_FAIL_CLOSED" for case in results)
        )

    def test_missing_appearance_lock_is_exact_not_partial(self) -> None:
        candidate = self.candidate()
        candidate["releaseAuthorities"]["appearanceLock"]["documentPath"] = (
            "docs/production/evidence/INTEGRATION/unpublished-lock.json"
        )
        self.assert_rejected("APPEARANCE_LOCK_GATE_MISMATCH", candidate)

    def test_missing_source_profile_is_exact_not_partial(self) -> None:
        candidate = self.candidate()
        candidate["releaseAuthorities"]["sourceProductionProfile"]["sha256"] = (
            "a" * 64
        )
        self.assert_rejected(
            "SOURCE_PRODUCTION_PROFILE_GATE_MISMATCH", candidate
        )

    def test_race_and_early_consumers_reject(self) -> None:
        mutations = (
            (("provenanceRgba", "jobs", "A", "state"), "running"),
            (("identityJoin", "invocations"), 1),
            (("normalizationRepeat", "jobs", "B", "invocations"), 1),
            (("literalScale", "jobs", "grayscale", "state"), "running"),
            (("assembler", "invocations"), 1),
        )
        for keys, value in mutations:
            with self.subTest(keys=keys):
                candidate = self.candidate()
                target = candidate["fanout"]
                for key in keys[:-1]:
                    target = target[key]
                target[keys[-1]] = value
                self.assert_rejected("EARLY_CONSUMER", candidate)

    def test_overlapping_roots_reject_before_binding_check(self) -> None:
        candidate = self.candidate()
        roots = candidate["fanout"]["provenanceRgba"]["jobs"]
        roots["B"]["evidenceRoot"] = roots["A"]["evidenceRoot"]
        self.assert_rejected("ROOT_OVERLAP", candidate)

    def test_overwrite_policy_and_preexisting_output_reject(self) -> None:
        candidate = self.candidate()
        candidate["rootPolicy"]["noOverwrite"] = False
        self.assert_rejected("OVERWRITE_POLICY_MISMATCH", candidate)
        first_root = validator.EXPECTED_ROOTS["provenance-rgba-A"]
        self.assert_rejected(
            "OUTPUT_ROOT_PREEXISTS",
            self.payload,
            root_probe=lambda path: "exists" if path == first_root else "missing",
        )

    def test_symlink_output_rejects_without_creating_symlink(self) -> None:
        first_root = validator.EXPECTED_ROOTS["provenance-rgba-A"]
        self.assert_rejected(
            "SYMLINK_OUTPUT_ROOT",
            self.payload,
            root_probe=lambda path: "symlink" if path == first_root else "missing",
        )

    def test_sibling_and_unsafe_paths_reject(self) -> None:
        mutations = (
            (
                "SIBLING_PATH_SUBSTITUTION",
                (
                    "docs/production/evidence/PLAY-081/"
                    "industrial-l04-west-source-v01/post-raw/process-A/"
                ),
            ),
            (
                "UNSAFE_OUTPUT_ROOT",
                f"{validator.EVIDENCE_ROOT}../../../../Rendering/",
            ),
            ("UNSAFE_OUTPUT_ROOT", "/tmp/play-080-escape/"),
        )
        for expected, value in mutations:
            with self.subTest(expected=expected, value=value):
                candidate = self.candidate()
                candidate["fanout"]["provenanceRgba"]["jobs"]["A"][
                    "evidenceRoot"
                ] = value
                self.assert_rejected(expected, candidate)

    def test_orientation_transform_rejects(self) -> None:
        candidate = self.candidate()
        candidate["orientationTransform"] = "mirror-x"
        self.assert_rejected("ORIENTATION_TRANSFORM_FORBIDDEN", candidate)

    def test_stale_master_claim_and_frozen_input_reject(self) -> None:
        cases = (
            (
                "STALE_INTEGRATION_AUTHORITY",
                ("integrationAuthority", "commit"),
            ),
            ("WRONG_CLAIM", ("claim", "sha256")),
            (
                "FROZEN_INPUT_MISMATCH",
                ("frozenInputs", "runner", "sha256"),
            ),
        )
        for expected, keys in cases:
            with self.subTest(expected=expected):
                candidate = self.candidate()
                target = candidate
                for key in keys[:-1]:
                    target = target[key]
                target[keys[-1]] = "a" * len(str(target[keys[-1]]))
                self.assert_rejected(expected, candidate)

    def test_duplicate_keys_and_nonfinite_numbers_reject(self) -> None:
        with self.assertRaises(validator.FanoutRejected) as duplicate:
            validator.load_json_bytes(b'{"a":1,"a":2}', "duplicate")
        self.assertEqual("DUPLICATE_JSON_KEY", duplicate.exception.code)
        with self.assertRaises(validator.FanoutRejected) as nonfinite:
            validator.load_json_bytes(b'{"value":NaN}', "nonfinite")
        self.assertEqual("NONFINITE_JSON_NUMBER", nonfinite.exception.code)

    def test_cli_dry_run_is_repeat_identical_and_writes_nothing(self) -> None:
        proof_path = validator.REPOSITORY_ROOT / validator.PROOF_PATH
        before = proof_path.read_bytes() if proof_path.exists() else None
        command = [
            sys.executable,
            str(validator.REPOSITORY_ROOT / validator.VALIDATOR_PATH),
            "--dry-run",
        ]
        first = subprocess.run(
            command,
            cwd=validator.REPOSITORY_ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        second = subprocess.run(
            command,
            cwd=validator.REPOSITORY_ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(0, first.returncode, first.stderr)
        self.assertEqual(first.stdout, second.stdout)
        report = json.loads(first.stdout)
        self.assertEqual("PASS_PRELOCK_BLOCKED", report["result"])
        self.assertTrue(report["replayIdentical"])
        self.assertFalse(report["reportWritten"])
        self.assertEqual(0, report["pixelFiles"])
        after = proof_path.read_bytes() if proof_path.exists() else None
        self.assertEqual(before, after)

    def test_cli_rejects_alternate_contract_and_proof_paths(self) -> None:
        script = str(validator.REPOSITORY_ROOT / validator.VALIDATOR_PATH)
        proof_path = validator.REPOSITORY_ROOT / validator.PROOF_PATH
        before = proof_path.read_bytes() if proof_path.exists() else None
        cases = (
            (
                "--contract",
                validator.CONTRACT_PATH.replace("PLAY-080", "PLAY-079"),
                "CONTRACT_PATH_MISMATCH",
            ),
            (
                "--proof",
                "../../Native/CitySimNative/Rendering/escape.json",
                "PROOF_PATH_MISMATCH",
            ),
        )
        for option, value, expected in cases:
            with self.subTest(option=option):
                result = subprocess.run(
                    [sys.executable, script, "--dry-run", option, value],
                    cwd=validator.REPOSITORY_ROOT,
                    text=True,
                    capture_output=True,
                    check=False,
                )
                self.assertEqual(2, result.returncode)
                self.assertEqual(expected, json.loads(result.stdout)["code"])
                after = proof_path.read_bytes() if proof_path.exists() else None
                self.assertEqual(before, after)


if __name__ == "__main__":
    unittest.main()
