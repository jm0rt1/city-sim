#!/usr/bin/env python3
"""Focused tests for exact dispatch identity resolution."""

from __future__ import annotations

import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("resolve_dispatch_identity_v1.py")
SPEC = importlib.util.spec_from_file_location("dispatch_identity", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class DispatchIdentityTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.repo = Path(self.temporary.name)
        subprocess.run(["git", "init", "-q", str(self.repo)], check=True)
        subprocess.run(["git", "-C", str(self.repo), "config", "user.email", "test@example.com"], check=True)
        subprocess.run(["git", "-C", str(self.repo), "config", "user.name", "Test"], check=True)
        (self.repo / "file.txt").write_text("identity\n", encoding="utf-8")
        subprocess.run(["git", "-C", str(self.repo), "add", "file.txt"], check=True)
        subprocess.run(["git", "-C", str(self.repo), "commit", "-q", "-m", "identity"], check=True)
        self.head = subprocess.run(
            ["git", "-C", str(self.repo), "rev-parse", "HEAD"],
            check=True, capture_output=True, text=True,
        ).stdout.strip()

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_resolves_full_commit_and_tree(self) -> None:
        receipt = MODULE.build_receipt(self.repo, ["HEAD"], [])
        identity = receipt["identities"][0]
        self.assertEqual(identity["commit"], self.head)
        self.assertTrue(MODULE.is_full_sha(identity["tree"]))

    def test_exact_expectation_passes(self) -> None:
        receipt = MODULE.build_receipt(self.repo, ["HEAD"], [f"HEAD={self.head}"])
        self.assertTrue(receipt["expectationsVerified"])

    def test_abbreviated_expectation_is_rejected(self) -> None:
        with self.assertRaises(MODULE.IdentityError):
            MODULE.build_receipt(self.repo, ["HEAD"], [f"HEAD={self.head[:8]}"])

    def test_wrong_full_expectation_is_rejected(self) -> None:
        with self.assertRaises(MODULE.IdentityError):
            MODULE.build_receipt(self.repo, ["HEAD"], [f"HEAD={'0' * 40}"])

    def test_duplicate_or_unrequested_refs_are_rejected(self) -> None:
        with self.assertRaises(MODULE.IdentityError):
            MODULE.build_receipt(self.repo, ["HEAD", "HEAD"], [])
        with self.assertRaises(MODULE.IdentityError):
            MODULE.build_receipt(self.repo, ["HEAD"], [f"master={self.head}"])


if __name__ == "__main__":
    unittest.main()
