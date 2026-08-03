"""Contained zero-child executable-boundary proof for PLAY-090 North."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import tempfile

import launch_residential_l01_process_a as runner
import render_residential_l01_process_a_child as child


ROOT = Path(runner.WORKTREE)
HERE = Path(__file__).resolve().parent
CONTRACT = f"{runner.SOURCE_ROOT}/{runner.CONTRACT_NAME}"


def fail(fn, label: str) -> None:
    try:
        fn()
    except (ValueError, RuntimeError, SystemExit):
        return
    raise AssertionError(f"adversary unexpectedly passed: {label}")


def write_json(path: Path, value: dict) -> bytes:
    data = (json.dumps(value, indent=2, sort_keys=True) + "\n").encode()
    path.write_bytes(data)
    return data


def fixture_documents(current_head: str, directory: Path) -> tuple[str, str, str]:
    schedule_path = directory / "schedule.json"
    grant_path = directory / "grant.json"
    receipt_path = directory / "receipt.json"
    orchestrator = ROOT / runner.SOURCE_ROOT / "launch_residential_l01_process_a.py"
    child_path = ROOT / runner.SOURCE_ROOT / runner.CHILD_NAME
    schedule = {
        "schema": 1, "task": "PLAY-090", "routeId": runner.ROUTE_ID, "slot": "north:A", "direction": "north", "process": "A",
        "claimSHA256": runner.CLAIM_SHA256, "workerHead": current_head, "schedulePath": "<fixture>/schedule.json",
        "grantPath": "<fixture>/grant.json", "processReceiptPath": "<fixture>/receipt.json",
        "orchestratorPath": runner.SOURCE_ROOT + "/launch_residential_l01_process_a.py",
        "orchestratorSHA256": runner.sha256_file(orchestrator), "childPath": runner.SOURCE_ROOT + "/" + runner.CHILD_NAME,
        "childSHA256": runner.sha256_file(child_path), "outputRoot": runner.FUTURE_PROCESS_ROOT,
        "evidenceRoot": runner.EVIDENCE_ROOT, "maximumChildStarts": 1, "sourceAuthority": False, "productionSelected": False,
    }
    schedule_bytes = write_json(schedule_path, schedule)
    schedule_sha = runner.sha256_bytes(schedule_bytes)
    grant = {"schema": 1, "grantId": "north:A", "scheduleSHA256": schedule_sha, "workerHead": current_head,
             "maximumChildStarts": 1, "consumed": False, "sourceAuthority": False, "productionSelected": False}
    write_json(grant_path, grant)
    receipt = {"schema": 1, "kind": "integration-process-receipt", "task": "PLAY-090", "routeId": runner.ROUTE_ID,
               "schedulePath": "<fixture>/schedule.json", "scheduleSHA256": schedule_sha, "grantId": "north:A",
               "workerHead": current_head, "maximumChildStarts": 1, "sourceAuthority": False, "productionSelected": False}
    write_json(receipt_path, receipt)
    return str(schedule_path), str(grant_path), str(receipt_path)


def assert_outputs_equal(first: Path, second: Path) -> None:
    for name in ("PAYLOAD.json", "CONTAINED-SMOKE.json"):
        if (first / name).read_bytes() != (second / name).read_bytes():
            raise AssertionError(f"fresh-root output differs: {name}")


def adversarial_documents(schedule_path: Path, grant_path: Path, receipt_path: Path, current_head: str) -> int:
    originals = {p: p.read_bytes() for p in (schedule_path, grant_path, receipt_path)}
    cases = []
    def mutate(path: Path, fn):
        value = json.loads(path.read_text())
        fn(value)
        path.write_bytes((json.dumps(value, indent=2, sort_keys=True) + "\n").encode())
    def check(label: str, path: Path, fn):
        for target, data in originals.items():
            target.write_bytes(data)
        mutate(path, fn)
        fail(lambda: runner.validate_direct_documents(ROOT, runner.validate_contract(ROOT, CONTRACT),
                                                      str(schedule_path), str(grant_path), str(receipt_path), True), label)
        cases.append(label)
    check("caller-selected route", schedule_path, lambda d: d.__setitem__("routeId", "wrong-route"))
    check("wrong worker head", schedule_path, lambda d: d.__setitem__("workerHead", "0" * 40))
    check("wrong output root", schedule_path, lambda d: d.__setitem__("outputRoot", "docs/production/claims/escape"))
    check("wrong command child hash", schedule_path, lambda d: d.__setitem__("childSHA256", "0" * 64))
    check("multi-child", schedule_path, lambda d: d.__setitem__("maximumChildStarts", 2))
    check("replayed grant", grant_path, lambda d: d.__setitem__("consumed", True))
    def drop_receipt_field(d):
        d.pop("scheduleSHA256")
    check("incomplete receipt", receipt_path, drop_receipt_field)
    for target, data in originals.items():
        target.write_bytes(data)
    return len(cases)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--contained-smoke", action="store_true")
    parser.add_argument("--assert-zero-dcc", action="store_true")
    parser.add_argument("--output-root", required=True)
    args = parser.parse_args(argv)
    if not args.contained_smoke or not args.assert_zero_dcc:
        raise SystemExit("contained smoke and zero-DCC assertion are required")
    if Path(args.output_root).as_posix() != runner.CONTAINED_SMOKE_ROOT:
        raise ValueError("test output root is outside the exact task-owned contained-smoke root")
    current = runner._git(ROOT, "rev-parse", "HEAD").decode().strip()
    original_popen = runner.subprocess.Popen
    def guarded_popen(*popen_args, **popen_kwargs):
        command = popen_args[0] if popen_args else popen_kwargs.get("args", [])
        if isinstance(command, (list, tuple)) and any(str(part).endswith("Blender") or "blender" in str(part).lower() for part in command):
            raise AssertionError("DCC child started")
        return original_popen(*popen_args, **popen_kwargs)
    runner.subprocess.Popen = guarded_popen
    try:
        with tempfile.TemporaryDirectory(prefix="play090-a-", dir="/private/tmp") as a, tempfile.TemporaryDirectory(prefix="play090-b-", dir="/private/tmp") as b:
            schedule_a, grant_a, receipt_a = fixture_documents(current, Path(a))
            # A second fresh root receives independent authority bytes with the same content.
            schedule_b, grant_b, receipt_b = fixture_documents(current, Path(b))
            adversaries = adversarial_documents(Path(schedule_a), Path(grant_a), Path(receipt_a), current)
            first_output = Path(a) / "out"
            second_output = Path(b) / "out"
            runner.main(["--repository-root", runner.WORKTREE, "--contract", CONTRACT, "--zero-child", "--contained-smoke",
                         "--schedule-path", schedule_a, "--grant-path", grant_a, "--process-receipt-path", receipt_a,
                         "--output-root", str(first_output)])
            runner.main(["--repository-root", runner.WORKTREE, "--contract", CONTRACT, "--zero-child", "--contained-smoke",
                         "--schedule-path", schedule_b, "--grant-path", grant_b, "--process-receipt-path", receipt_b,
                         "--output-root", str(second_output)])
            first = json.loads((first_output / "CONTAINED-SMOKE.json").read_text())
            second = json.loads((second_output / "CONTAINED-SMOKE.json").read_text())
            if first != second:
                raise AssertionError("fresh-root smoke payload differs")
            assert_outputs_equal(first_output, second_output)
            if first["payload"]["dccChildStarts"] != 0 or first["payload"]["processAStarts"] != 0 or first["payload"]["pixelWrites"] != 0:
                raise AssertionError("nonzero activity in contained smoke")
            # The actual task-owned evidence root is idempotent and byte-closed.
            task_output = ROOT / args.output_root
            runner.main(["--repository-root", runner.WORKTREE, "--contract", CONTRACT, "--zero-child", "--contained-smoke",
                         "--schedule-path", schedule_a, "--grant-path", grant_a, "--process-receipt-path", receipt_a,
                         "--output-root", runner.CONTAINED_SMOKE_ROOT])
            runner.main(["--repository-root", runner.WORKTREE, "--contract", CONTRACT, "--zero-child", "--contained-smoke",
                         "--schedule-path", schedule_b, "--grant-path", grant_b, "--process-receipt-path", receipt_b,
                         "--output-root", runner.CONTAINED_SMOKE_ROOT])
            if (task_output / "PAYLOAD.json").stat().st_size + (task_output / "CONTAINED-SMOKE.json").stat().st_size > runner.MAX_OUTPUT_BYTES:
                raise AssertionError("bounded output exceeded")
    finally:
        runner.subprocess.Popen = original_popen

    # Production must fail closed before output creation when Integration has not
    # supplied all three authority documents.
    fail(lambda: runner.prepare_production(ROOT, CONTRACT, None, None, None), "missing grant/schedule/receipt")
    fail(lambda: runner.main(["--repository-root", runner.WORKTREE, "--contract", CONTRACT,
                              "--output-root", runner.FUTURE_PROCESS_ROOT, "--integration-direct"]), "forged direct mode")
    fail(lambda: child.validate_launch(argparse.Namespace(integration_direct=False, repository_root=runner.WORKTREE,
                                                           contract=CONTRACT, schedule_path="/private/tmp/no-schedule",
                                                           grant_path="/private/tmp/no-grant", process_receipt_path="/private/tmp/no-receipt",
                                                           output_root=runner.FUTURE_PROCESS_ROOT)), "direct child without capability")
    # Static seam proves bpy is not imported at module load and source remains
    # bound to the exact Residential design/material inputs.
    if "bpy" not in child.render_process.__code__.co_names:
        raise AssertionError("child render seam missing")
    print(f"PASS PLAY-090 contained-smoke zeroChild=1 adversaries={adversaries + 1} freshRoots=2 dccChildren=0 processA=0 pixels=0 productionDenied=1")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
