#!/usr/bin/env python3
"""Focused adversarial tests for the PLAY-106 South authoring ledger."""

from __future__ import annotations

import copy
import unittest
from pathlib import Path

import validate_aggregate_manifest_v1 as validator


class AggregateManifestValidatorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.root = validator.repo_root()
        cls.report = validator.run_once(cls.root)

    def test_publishes_exact_deterministic_43_row_ledger(self) -> None:
        rows = self.report["canonicalSouthAuthoringRows"]
        self.assertEqual(len(rows), 43)
        self.assertEqual(len({row["logicalId"] for row in rows}), 43)
        self.assertEqual(
            self.report["canonicalSouthAuthoringDigestSha256"],
            validator.canonical_authoring_digest(rows),
        )
        self.assertEqual(
            validator.canonical(self.report),
            validator.canonical(validator.run_once(self.root)),
        )

    def test_selects_v01_and_preserves_v02_as_excluded_evidence(self) -> None:
        selected = next(
            row
            for row in self.report["canonicalSouthAuthoringRows"]
            if row["logicalId"] == validator.INDUSTRIAL_CANONICAL_ID
        )
        self.assertEqual(selected["path"], validator.INDUSTRIAL_CANONICAL_PATH)
        self.assertEqual(selected["sha256"], validator.INDUSTRIAL_CANONICAL_SHA)
        self.assertNotIn(
            validator.INDUSTRIAL_EXCLUDED_PATH,
            {row["path"] for row in self.report["canonicalSouthAuthoringRows"]},
        )
        excluded = self.report["excludedRawEvidence"]
        self.assertEqual(len(excluded), 1)
        self.assertEqual(excluded[0]["path"], validator.INDUSTRIAL_EXCLUDED_PATH)
        self.assertEqual(excluded[0]["sha256"], validator.INDUSTRIAL_EXCLUDED_SHA)
        self.assertEqual(excluded[0]["disposition"], validator.INDUSTRIAL_EXCLUDED_DISPOSITION)
        self.assertFalse(excluded[0]["retryAllowed"])
        self.assertEqual(set(excluded[0]["countsToward"].values()), {False})
        self.assertEqual(len(self.report["rawFiles"]), 44)

    def test_canonical_hash_tamper_is_rejected(self) -> None:
        tampered = copy.deepcopy(self.report)
        tampered["canonicalSouthAuthoringRows"][0]["sha256"] = "0" * 64
        tampered["canonicalSouthAuthoringDigestSha256"] = validator.canonical_authoring_digest(
            tampered["canonicalSouthAuthoringRows"]
        )
        self.assertIn(
            "canonical_authoring_sha_mismatch:residential_l01_v0",
            validator.validate_authoring_projection(tampered),
        )

    def test_duplicate_canonical_id_is_rejected(self) -> None:
        tampered = copy.deepcopy(self.report)
        tampered["canonicalSouthAuthoringRows"][1]["logicalId"] = tampered[
            "canonicalSouthAuthoringRows"
        ][0]["logicalId"]
        tampered["canonicalSouthAuthoringDigestSha256"] = validator.canonical_authoring_digest(
            tampered["canonicalSouthAuthoringRows"]
        )
        self.assertIn(
            "duplicate_canonical_authoring_ids",
            validator.validate_authoring_projection(tampered),
        )

    def test_false_readiness_and_product_flags_are_rejected(self) -> None:
        manifest = validator.build_manifest(self.root)
        for key in (
            "sourceReady",
            "integrationAdmitted",
            "rendererQuarantined",
            "productionSelected",
        ):
            tampered = copy.deepcopy(manifest)
            tampered["flags"][key] = True
            self.assertIn(f"flag_not_false:{key}", validator.validate_manifest(self.root, tampered))

        tampered = copy.deepcopy(self.report)
        tampered["canonicalSouthAuthoringRows"][0]["readiness"]["sourceReady"] = True
        tampered["canonicalSouthAuthoringDigestSha256"] = validator.canonical_authoring_digest(
            tampered["canonicalSouthAuthoringRows"]
        )
        self.assertIn(
            "canonical_authoring_readiness_not_false:residential_l01_v0",
            validator.validate_authoring_projection(tampered),
        )

    def test_only_directional_incompleteness_remains_fail_closed(self) -> None:
        self.assertEqual(self.report["status"], "FAIL_CLOSED")
        self.assertEqual(self.report["errors"], ["directional_payloads_incomplete"])
        self.assertTrue(self.report["checks"]["allFlagsFalse"])
        self.assertTrue(self.report["checks"]["directionalPayloadsIncomplete"])

    def test_absolute_output_path_is_displayable(self) -> None:
        output = Path("/private/tmp/PLAY-106-agent007-report-v1/report.json")
        self.assertEqual(validator.report_path_for_display(output, self.root), str(output))


if __name__ == "__main__":
    unittest.main()
