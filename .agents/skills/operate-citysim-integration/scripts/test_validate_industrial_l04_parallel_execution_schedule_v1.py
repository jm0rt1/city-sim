#!/usr/bin/env python3
"""No-DCC adversarial tests for the Industrial L4 schedule validator."""

from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
VALIDATOR = Path(__file__).with_name("validate_industrial_l04_parallel_execution_schedule_v1.py")
SPEC = importlib.util.spec_from_file_location("schedule_validator", VALIDATOR)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class ScheduleValidatorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        family = ROOT / "docs/production/decisions/CONTRACT-010-directional-building-art.md"
        orchestrator = ROOT / ".agents/skills/operate-citysim-integration/scripts/validate_world_art_parallel_state.py"
        direction_specs = {
            "north": ("PLAY-027", "codex/citysim-world-art"),
            "east": ("PLAY-079", "codex/citysim-world-art-east"),
            "south": ("PLAY-080", "codex/citysim-world-art-south"),
            "west": ("PLAY-081", "codex/citysim-world-art-west"),
        }
        grants = []
        for direction, (claim, branch) in direction_specs.items():
            processes = []
            for process in ("A", "B", "C"):
                granted = direction == "north" and process == "A"
                processes.append(
                    {
                        "grantId": f"test-{direction}-{process}",
                        "process": process,
                        "state": "granted" if granted else "blocked",
                        "slotId": "dcc-1" if granted else None,
                        "maximumChildStarts": 1 if granted else 0,
                        "orchestratorOnly": True,
                        "directLowLevelInvocationAllowed": False,
                    }
                )
            grants.append(
                {
                    "direction": direction,
                    "claim": claim,
                    "branch": branch,
                    "claimSha256": "0" * 64,
                    "baseCommit": self.head,
                    "orchestrator": {
                        "path": str(orchestrator.relative_to(ROOT)),
                        "sha256": sha(orchestrator),
                    },
                    "exclusiveRoots": [f"Native/test/{direction}", f"docs/test/{direction}"],
                    "processes": processes,
                }
            )
        self.valid = {
            "schema": 1,
            "batch": "industrial_l04_directional_family",
            "phase": "prelock_north_a",
            "issuedAt": "2026-07-30T00:00:00Z",
            "integrationAuthorityCommit": self.head,
            "familyContract": {
                "path": str(family.relative_to(ROOT)),
                "sha256": sha(family),
            },
            "appearanceLock": None,
            "sourceProductionProfile": None,
            "computeEnvelope": {
                "maximumSimultaneousDCCProcesses": 1,
                "slotIds": ["dcc-1"],
                "queueOrder": ["north:A"],
            },
            "directionGrants": grants,
        }

    def write(self, data: dict) -> Path:
        handle = tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False)
        json.dump(data, handle)
        handle.close()
        return Path(handle.name)

    def assert_fails(self, mutate) -> None:
        data = copy.deepcopy(self.valid)
        mutate(data)
        with self.assertRaises(MODULE.ScheduleError):
            MODULE.validate(ROOT, self.write(data))

    def test_valid_prelock_schedule(self) -> None:
        result = MODULE.validate(ROOT, self.write(self.valid))
        self.assertEqual(result["grantedProcesses"], ["north:A"])

    def test_rejects_sibling_pixel_grant_before_lock(self) -> None:
        def mutate(data):
            process = data["directionGrants"][1]["processes"][0]
            process.update(state="granted", slotId="dcc-1", maximumChildStarts=1)
            data["computeEnvelope"]["queueOrder"].append("east:A")
        self.assert_fails(mutate)

    def test_rejects_direct_low_level_invocation(self) -> None:
        self.assert_fails(
            lambda data: data["directionGrants"][0]["processes"][0].update(
                directLowLevelInvocationAllowed=True
            )
        )

    def test_rejects_more_than_one_child(self) -> None:
        self.assert_fails(
            lambda data: data["directionGrants"][0]["processes"][0].update(
                maximumChildStarts=2
            )
        )

    def test_rejects_stale_binding(self) -> None:
        self.assert_fails(lambda data: data["familyContract"].update(sha256="f" * 64))

    def test_rejects_duplicate_owned_root(self) -> None:
        self.assert_fails(
            lambda data: data["directionGrants"][1]["exclusiveRoots"].__setitem__(
                0, data["directionGrants"][0]["exclusiveRoots"][0]
            )
        )

    def test_rejects_queue_that_omits_grant(self) -> None:
        self.assert_fails(lambda data: data["computeEnvelope"].update(queueOrder=[]))

    def test_rejects_postlock_without_lock_or_profile(self) -> None:
        self.assert_fails(lambda data: data.update(phase="postlock_abc"))


if __name__ == "__main__":
    unittest.main()
