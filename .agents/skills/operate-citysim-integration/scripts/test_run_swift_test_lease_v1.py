#!/usr/bin/env python3
"""Adversarial proof for the descendant-safe Swift-test lease runner."""

from __future__ import annotations

import hashlib
import json
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path


RUNNER = Path(__file__).with_name("run_swift_test_lease_v1.py")


class SwiftTestLeaseTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.locks = self.root / "locks"
        self.build = self.root / "build"
        self.build.mkdir()

    def tearDown(self) -> None:
        self.temp.cleanup()

    def invoke(
        self, lease: str, code: str, *, build: Path | None = None,
        produced: Path | None = None,
    ) -> subprocess.CompletedProcess[str]:
        stem = f"{lease}-{time.time_ns()}"
        produced_args = (
            ["--produced-test-bundle-executable", str(produced)]
            if produced is not None else []
        )
        return subprocess.run(
            [sys.executable, str(RUNNER), "--lease-id", lease, "--build-root", str(build or self.build),
             "--lock-dir", str(self.locks), "--log", str(self.root / f"{stem}.log"),
             "--metadata", str(self.root / f"{stem}.json"), *produced_args,
             "--", sys.executable, "-c", code],
            text=True, capture_output=True, check=False,
        )

    def command(self, lease: str, code: str, *, build: Path | None = None) -> list[str]:
        stem = f"{lease}-{time.time_ns()}"
        return [sys.executable, str(RUNNER), "--lease-id", lease, "--build-root", str(build or self.build),
                "--lock-dir", str(self.locks), "--log", str(self.root / f"{stem}.log"),
                "--metadata", str(self.root / f"{stem}.json"), "--", sys.executable, "-c", code]

    def assert_pass_metadata(self, result: subprocess.CompletedProcess[str]) -> dict:
        self.assertEqual(result.returncode, 0, result.stderr)
        metadata = sorted(self.root.glob("*.json"))[-1]
        value = json.loads(metadata.read_text(encoding="utf-8"))
        self.assertEqual(value["status"], "terminal")
        self.assertTrue(value["terminal"])
        self.assertTrue(value["parentExited"])
        self.assertTrue(value["processGroupExited"])
        self.assertTrue(value["descendantsExited"])
        self.assertEqual(value["exitCode"], 0)
        self.assertEqual(value["validatorExitCode"], 0)
        self.assertTrue(value["logSha256"])
        self.assertTrue(value["utcStarted"].endswith("Z"))
        self.assertTrue(value["utcEnded"].endswith("Z"))
        self.assertEqual(value["rootLockPid"], value["leasePid"])
        self.assertEqual(value["rootLockPgid"], value["leasePgid"])
        self.assertEqual(value["lockDir"], str(self.locks.resolve()))
        self.assertEqual(value["argv"][-3:], [sys.executable, "-c", value["argv"][-1]])
        self.assertTrue(value["literalCommand"])
        return value

    def test_result_bearing_pass_captures_original_combined_log(self) -> None:
        result = self.invoke("pass", "import sys; print('Test run with 2 tests passed'); print('stderr', file=sys.stderr)")
        value = self.assert_pass_metadata(result)
        log = next(self.root.glob("pass-*.log")).read_text(encoding="utf-8")
        self.assertIn("Test run with 2 tests passed", log)
        self.assertIn("stderr", log)
        self.assertEqual(value["parentPgid"], value["parentPid"])

    def test_nonzero_exit_is_preserved(self) -> None:
        result = self.invoke("nonzero", "print('Test run with 1 test passed'); raise SystemExit(7)")
        self.assertEqual(result.returncode, 7)

    def test_compilation_only_log_is_rejected(self) -> None:
        result = self.invoke("compile", "print('Build complete!')")
        self.assertEqual(result.returncode, 1)

    def test_result_receipt_binds_exact_produced_xctest_executable(self) -> None:
        executable = (
            self.build / "debug" / "FixtureTests.xctest" / "Contents" /
            "MacOS" / "FixtureTests"
        )
        executable.parent.mkdir(parents=True)
        executable.write_bytes(b"fresh test bundle\n")
        executable.chmod(0o755)
        value = self.assert_pass_metadata(self.invoke(
            "produced", "print('Test run with 1 test passed')", produced=executable
        ))
        self.assertEqual(value["producedTestBundleExecutable"], {
            "path": str(executable.resolve()),
            "sha256": hashlib.sha256(executable.read_bytes()).hexdigest(),
        })
        self.assertIsNone(value["producedTestBundleError"])

    def test_missing_produced_xctest_executable_fails_terminal_receipt(self) -> None:
        missing = self.build / "debug" / "MissingTests.xctest" / "Contents" / "MacOS" / "MissingTests"
        result = self.invoke(
            "missing-produced", "print('Test run with 1 test passed')", produced=missing
        )
        self.assertEqual(result.returncode, 4)
        self.assertIn("does not exist", result.stderr)
        receipt = sorted(self.root.glob("*.json"))[-1]
        value = json.loads(receipt.read_text(encoding="utf-8"))
        self.assertTrue(value["terminal"])
        self.assertNotIn("producedTestBundleExecutable", value)

    def test_stale_lock_file_does_not_block_new_os_lock_holder(self) -> None:
        self.locks.mkdir()
        import hashlib
        stale = self.locks / f"lease-{hashlib.sha256(b'stale').hexdigest()}.lock"
        stale.write_text('{"status":"stale"}\n', encoding="utf-8")
        self.assert_pass_metadata(self.invoke("stale", "print('Test run with 1 test passed')"))

    def test_same_lease_contention_is_rejected(self) -> None:
        first = subprocess.Popen(self.command("shared", "import time; time.sleep(.45); print('Test run with 1 test passed')"))
        time.sleep(.10)
        second = self.invoke("shared", "print('Test run with 1 test passed')")
        self.assertEqual(second.returncode, 2)
        self.assertIn("LEASE_CONTENTION", second.stderr)
        self.assertEqual(first.wait(timeout=3), 0)

    def test_same_build_root_contention_is_rejected(self) -> None:
        first = subprocess.Popen(self.command("first", "import time; time.sleep(.45); print('Test run with 1 test passed')"))
        time.sleep(.10)
        second = self.invoke("second", "print('Test run with 1 test passed')")
        self.assertEqual(second.returncode, 3)
        self.assertIn("BUILD_ROOT_CONTENTION", second.stderr)
        self.assertEqual(first.wait(timeout=3), 0)

    def test_child_linger_holds_lock_until_process_group_clears(self) -> None:
        code = "import subprocess,sys; subprocess.Popen([sys.executable,'-c','import time; time.sleep(.25)']); print('Test run with 1 test passed')"
        started = time.monotonic()
        self.assert_pass_metadata(self.invoke("linger", code))
        self.assertGreaterEqual(time.monotonic() - started, .20)

    def test_process_group_escape_is_observed_before_unlock(self) -> None:
        code = "import subprocess,sys,time; subprocess.Popen([sys.executable,'-c','import os,time; os.setsid(); time.sleep(.28)']); time.sleep(.12); print('Test run with 1 test passed')"
        started = time.monotonic()
        value = self.assert_pass_metadata(self.invoke("escape", code))
        self.assertGreaterEqual(time.monotonic() - started, .24)
        self.assertTrue(value["observedDescendants"])

    def test_observed_escapee_forking_later_is_followed(self) -> None:
        child = (
            "import os,subprocess,sys,time; os.setsid(); time.sleep(.12); "
            "subprocess.Popen([sys.executable,'-c','import time; time.sleep(.25)']); time.sleep(.03)"
        )
        code = (
            "import subprocess,sys,time; "
            f"subprocess.Popen([sys.executable,'-c',{child!r}]); "
            "time.sleep(.08); print('Test run with 1 test passed')"
        )
        started = time.monotonic()
        value = self.assert_pass_metadata(self.invoke("late-fork", code))
        self.assertGreaterEqual(time.monotonic() - started, .30)
        self.assertGreaterEqual(len(value["observedDescendants"]), 2)


if __name__ == "__main__":
    unittest.main()
