#!/usr/bin/env python3
from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import os
import platform
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parents[3]
SCHEMA = REPO_ROOT / "docs/production/evidence/INTEGRATION/residential-l01-variant1-north-process-a-schedule-schema-v1.json"
SPEC = importlib.util.spec_from_file_location("validator", HERE / "validate_residential_l01_variant1_north_process_a_schedule_v1.py")
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(MODULE)


def sha(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def write(root: Path, relative: str, payload: bytes | str) -> Path:
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(payload.encode() if isinstance(payload, str) else payload)
    return path


def run(root: Path, *args: str) -> str:
    result = subprocess.run(args, cwd=root, check=True, capture_output=True, text=True)
    return result.stdout.strip()


class ScheduleValidatorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="play090-schedule-")
        self.base = Path(self.temp.name)
        self.repo = self.base / "authority"
        self.worker = self.base / "worker"
        self.repo.mkdir()
        run(self.repo, "git", "init")
        run(self.repo, "git", "checkout", "-b", "master")
        run(self.repo, "git", "config", "user.email", "tests@citysim.invalid")
        run(self.repo, "git", "config", "user.name", "CitySim Tests")

        executable = self.base / "Blender"
        shutil.copyfile("/bin/echo", executable)
        executable.chmod(0o755)
        file_text = subprocess.run(["/usr/bin/file", str(executable)], check=True, capture_output=True, text=True).stdout
        machine = platform.machine()
        self.arch = machine if machine in file_text else ("arm64" if "arm64" in file_text else "x86_64")
        self.executable = executable
        self.executable_sha = sha(executable.read_bytes())

        family = "# CONTRACT-023\nIntegration alone owns Process A authority.\n"
        claim = (
            "# PLAY-090 Claim\n"
            f"Branch `{MODULE.BRANCH}` worktree {MODULE.WORKTREE}\n"
            f"{MODULE.SOURCE_ROOT}\n{MODULE.EVIDENCE_ROOT}\n"
        )
        startup = {
            "schema": 1,
            "startupPass": True,
            "binary": {"path": str(executable), "architecture": self.arch, "version": "4.5.12 LTS", "buildHash": "84afd5f785f7"},
            "processAccounting": {"activeBlenderAfterProbe": False},
        }
        self.family_bytes = family.encode()
        self.claim_bytes = claim.encode()
        self.startup_bytes = (json.dumps(startup, sort_keys=True, separators=(",", ":")) + "\n").encode()
        write(self.repo, MODULE.FAMILY_PATH, self.family_bytes)
        write(self.repo, MODULE.CLAIM_PATH, self.claim_bytes)
        write(self.repo, MODULE.STARTUP_PATH, self.startup_bytes)
        run(self.repo, "git", "add", MODULE.FAMILY_PATH, MODULE.CLAIM_PATH, MODULE.STARTUP_PATH)
        run(self.repo, "git", "commit", "-m", "authority")
        self.authority = run(self.repo, "git", "rev-parse", "HEAD")

        run(self.repo, "git", "worktree", "add", "-b", MODULE.BRANCH, str(self.worker), self.authority)
        self.orchestrator_bytes = b"#!/usr/bin/env python3\nprint('zero-child')\n"
        self.child_bytes = b"#!/usr/bin/env python3\nraise SystemExit('sealed')\n"
        write(self.worker, MODULE.ORCHESTRATOR_PATH, self.orchestrator_bytes)
        write(self.worker, MODULE.CHILD_PATH, self.child_bytes)
        run(self.worker, "git", "add", MODULE.ORCHESTRATOR_PATH, MODULE.CHILD_PATH)
        run(self.worker, "git", "commit", "-m", "worker implementation")
        self.worker_head = run(self.worker, "git", "rev-parse", "HEAD")

        self.grant_id = "play090-residential-v1-north-a-attempt-1"
        receipt = {
            "schema": 1,
            "taskId": "PLAY-090",
            "family": MODULE.BATCH,
            "direction": "north",
            "process": "A",
            "grantId": self.grant_id,
            "slotId": MODULE.SLOT,
            "authorityCommit": self.authority,
            "workerHead": self.worker_head,
            "claimSha256": sha(self.claim_bytes),
            "orchestratorSha256": sha(self.orchestrator_bytes),
            "childSha256": sha(self.child_bytes),
            "startupReceiptSha256": sha(self.startup_bytes),
            "executableSha256": self.executable_sha,
            "outputRoot": MODULE.OUTPUT_ROOT,
            "attemptMarker": MODULE.ATTEMPT_PATH,
            "maximumChildStarts": 1,
            "pixelProductionAuthorized": True,
            "consumed": False,
            "attemptCount": 0,
        }
        self.receipt = receipt
        self.receipt_bytes = (json.dumps(receipt, sort_keys=True, separators=(",", ":")) + "\n").encode()
        write(self.repo, MODULE.PROCESS_RECEIPT_PATH, self.receipt_bytes)
        run(self.repo, "git", "add", MODULE.PROCESS_RECEIPT_PATH)
        run(self.repo, "git", "commit", "-m", "process receipt")
        self.receipt_commit = run(self.repo, "git", "rev-parse", "HEAD")

        self.schedule = {
            "schema": 1,
            "batch": MODULE.BATCH,
            "phase": "prelock_north_a",
            "issuedAt": "2026-08-03T06:30:00Z",
            "integrationAuthorityCommit": self.authority,
            "familyContract": {"path": MODULE.FAMILY_PATH, "sha256": sha(self.family_bytes)},
            "claim": {"path": MODULE.CLAIM_PATH, "sha256": sha(self.claim_bytes)},
            "worker": {"threadId": MODULE.THREAD, "branch": MODULE.BRANCH, "worktree": MODULE.WORKTREE, "head": self.worker_head},
            "startupReceipt": {"path": MODULE.STARTUP_PATH, "sha256": sha(self.startup_bytes)},
            "executable": {
                "path": str(executable), "sha256": self.executable_sha, "architecture": self.arch,
                "version": "4.5.12 LTS", "buildHash": "84afd5f785f7",
                "factoryStartup": True, "autoexecDisabled": True,
            },
            "orchestrator": {"path": MODULE.ORCHESTRATOR_PATH, "sha256": sha(self.orchestrator_bytes)},
            "child": {"path": MODULE.CHILD_PATH, "sha256": sha(self.child_bytes)},
            "computeEnvelope": {"maximumSimultaneousDCCProcesses": 1, "slotIds": [MODULE.SLOT], "queueOrder": ["north:A"]},
            "northGrant": {
                "grantId": self.grant_id, "direction": "north", "process": "A", "state": "granted",
                "slotId": MODULE.SLOT, "maximumChildStarts": 1, "orchestratorOnly": True,
                "directLowLevelInvocationAllowed": False, "pixelProductionAuthorized": True,
            },
            "blockedProcesses": ["B", "C"],
            "blockedDirections": ["east", "south", "west"],
            "exclusiveRoots": {
                "sourceRoot": MODULE.SOURCE_ROOT, "evidenceRoot": MODULE.EVIDENCE_ROOT,
                "outputRoot": MODULE.OUTPUT_ROOT, "attemptMarker": MODULE.ATTEMPT_PATH,
            },
            "integrationProcessReceipt": {"path": MODULE.PROCESS_RECEIPT_PATH, "sha256": sha(self.receipt_bytes), "commit": self.receipt_commit},
            "productionBoundary": {
                "pixelsAuthorizedByGrantId": self.grant_id, "requireOutputRootAbsent": True,
                "requireAttemptMarkerAbsent": True, "maximumAttempts": 1,
                "appearanceLockPublished": False, "sourceAuthority": False,
                "productionSelected": False, "siblingPixelsAuthorized": False,
            },
        }
        self.schedule_path = self.base / "SCHEDULE.json"

    def tearDown(self) -> None:
        self.temp.cleanup()

    def validate(self, value=None):
        write(self.base, "SCHEDULE.json", json.dumps(self.schedule if value is None else value, indent=2) + "\n")
        return MODULE.validate(self.schedule_path, self.repo, self.worker)

    def invalid(self, mutate, message: str):
        value = copy.deepcopy(self.schedule)
        mutate(value)
        with self.assertRaisesRegex(MODULE.ScheduleError, message):
            self.validate(value)

    def recommit_receipt(self, mutate):
        receipt = copy.deepcopy(self.receipt)
        mutate(receipt)
        payload = (json.dumps(receipt, sort_keys=True, separators=(",", ":")) + "\n").encode()
        write(self.repo, MODULE.PROCESS_RECEIPT_PATH, payload)
        run(self.repo, "git", "add", MODULE.PROCESS_RECEIPT_PATH)
        run(self.repo, "git", "commit", "-m", "mutated process receipt")
        self.schedule["integrationProcessReceipt"] = {
            "path": MODULE.PROCESS_RECEIPT_PATH,
            "sha256": sha(payload),
            "commit": run(self.repo, "git", "rev-parse", "HEAD"),
        }

    def test_schema_document_is_valid_json(self):
        json.loads(SCHEMA.read_text())

    def test_valid_exact_one_slot_schedule(self):
        result = self.validate()
        self.assertEqual(result["grantedProcesses"], ["north:A"])
        self.assertEqual(result["maximumSimultaneousDCCProcesses"], 1)

    def test_rejects_unknown_top_level_field(self):
        self.invalid(lambda d: d.update(extra=True), "top-level fields")

    def test_rejects_unknown_worker_head_placeholder(self):
        self.invalid(lambda d: d["worker"].update(head="PENDING"), "worker.head invalid")

    def test_rejects_more_than_one_dcc_slot(self):
        self.invalid(lambda d: d["computeEnvelope"].update(maximumSimultaneousDCCProcesses=2), "one North-A slot")

    def test_rejects_non_north_queue(self):
        self.invalid(lambda d: d["computeEnvelope"].update(queueOrder=["north:A", "south:A"]), "one North-A slot")

    def test_rejects_process_b(self):
        self.invalid(lambda d: d["northGrant"].update(process="B"), "one-child orchestrator-only North A")

    def test_rejects_sibling_direction(self):
        self.invalid(lambda d: d["northGrant"].update(direction="east"), "one-child orchestrator-only North A")

    def test_rejects_more_than_one_child(self):
        self.invalid(lambda d: d["northGrant"].update(maximumChildStarts=2), "one-child orchestrator-only North A")

    def test_rejects_direct_child_invocation(self):
        self.invalid(lambda d: d["northGrant"].update(directLowLevelInvocationAllowed=True), "one-child orchestrator-only North A")

    def test_rejects_non_orchestrator_start(self):
        self.invalid(lambda d: d["northGrant"].update(orchestratorOnly=False), "one-child orchestrator-only North A")

    def test_rejects_unblocked_b_or_c(self):
        self.invalid(lambda d: d.update(blockedProcesses=["B"]), "B/C and sibling")

    def test_rejects_unblocked_sibling(self):
        self.invalid(lambda d: d.update(blockedDirections=["east", "south"]), "B/C and sibling")

    def test_rejects_pixel_authority_not_bound_to_grant(self):
        self.invalid(lambda d: d["productionBoundary"].update(pixelsAuthorizedByGrantId="other"), "pixel/source/production boundary")

    def test_rejects_sibling_pixel_authority(self):
        self.invalid(lambda d: d["productionBoundary"].update(siblingPixelsAuthorized=True), "pixel/source/production boundary")

    def test_rejects_stale_orchestrator_hash(self):
        self.invalid(lambda d: d["orchestrator"].update(sha256="0" * 64), "orchestrator does not match")

    def test_rejects_startup_executable_tuple_drift(self):
        self.invalid(lambda d: d["executable"].update(buildHash="wrong"), "startup receipt/executable tuple")

    def test_rejects_existing_output_root(self):
        (self.worker / MODULE.OUTPUT_ROOT).mkdir(parents=True)
        with self.assertRaisesRegex(MODULE.ScheduleError, "output root must be absent"):
            self.validate()

    def test_rejects_existing_attempt_marker(self):
        write(self.repo, MODULE.ATTEMPT_PATH, "{}\n")
        with self.assertRaisesRegex(MODULE.ScheduleError, "attempt marker must be absent"):
            self.validate()

    def test_rejects_tampered_process_receipt(self):
        write(self.repo, MODULE.PROCESS_RECEIPT_PATH, "{}\n")
        with self.assertRaisesRegex(MODULE.ScheduleError, "working bytes differ"):
            self.validate()

    def test_rejects_consumed_process_receipt(self):
        self.recommit_receipt(lambda receipt: receipt.update(consumed=True, attemptCount=1))
        with self.assertRaisesRegex(MODULE.ScheduleError, "process receipt does not exactly cross-bind"):
            self.validate()


if __name__ == "__main__":
    unittest.main(verbosity=2)
