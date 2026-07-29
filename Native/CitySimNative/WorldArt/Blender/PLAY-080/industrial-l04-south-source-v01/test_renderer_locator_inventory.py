#!/usr/bin/env python3
"""Focused portability test for the PLAY-080 Renderer locator inventory."""

from __future__ import annotations

import subprocess
import unittest
from unittest import mock

import validate_renderer_locator_inventory as validator


class RendererLocatorInventoryPortabilityTests(unittest.TestCase):
    def test_integration_history_does_not_require_worker_carriers(self) -> None:
        inventory = validator.load_json(validator.INVENTORY_PATH)
        authority = inventory["authority"]
        integration_head = authority["publishedMaster"]
        worker_carriers = (
            authority["acceptedSouthAncestor"],
            authority["inventoryBaseCommit"],
        )

        self.assertTrue(self.is_ancestor(integration_head, integration_head))
        for carrier in worker_carriers:
            self.assertFalse(
                self.is_ancestor(carrier, integration_head),
                f"fixture must exclude worker carrier {carrier}",
            )

        def integration_style_git(*arguments: str) -> str:
            values = {
                ("branch", "--show-current"): validator.BRANCH,
                ("rev-parse", "HEAD"): integration_head,
                ("rev-parse", "origin/master"): integration_head,
            }
            return values[arguments]

        with mock.patch.object(
            validator,
            "git",
            side_effect=integration_style_git,
        ):
            result = validator.validate_inventory(inventory)

        self.assertEqual(result["result"], "PASS")
        self.assertEqual(result["head"], integration_head)
        self.assertEqual(result["publishedMaster"], integration_head)
        self.assertEqual(result["locatorCount"], 62)
        self.assertFalse(
            result["workerProvenance"]["runtimeAncestryRequired"]
        )

    @staticmethod
    def is_ancestor(ancestor: str, descendant: str) -> bool:
        result = subprocess.run(
            [
                "git",
                "merge-base",
                "--is-ancestor",
                ancestor,
                descendant,
            ],
            cwd=validator.REPOSITORY_ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode not in (0, 1):
            raise AssertionError(result.stderr.strip())
        return result.returncode == 0


if __name__ == "__main__":
    unittest.main()
