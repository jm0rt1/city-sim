#!/usr/bin/env python3
"""Fail-closed launcher for one PLAY-027 v12 static Blender import."""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
import signal
import stat
import subprocess
import time
from pathlib import Path
from typing import Any


STATIC_CHILD_FILES = [
    "BLENDER-OBJECT-MANIFEST.json",
    "MATERIAL-MANIFEST.json",
    "PROJECTION.json",
    "TOPOLOGY.json",
    "INPUT-BINDINGS.json",
    "VALIDATION.json",
]
SOURCE_RELATIVE = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
    "industrial-l04-north-art-v12/blender-lowering-v01"
)


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"JSON object required: {path}")
    return value


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", required=True)
    parser.add_argument(
        "--process-id", choices=("static-a", "static-b"), required=True
    )
    return parser.parse_args()


def exact_regular(path: Path, expected_hash: str | None = None) -> Path:
    if path.is_symlink():
        raise RuntimeError(f"symlink input rejected: {path}")
    resolved = path.resolve(strict=True)
    if not stat.S_ISREG(resolved.stat().st_mode):
        raise RuntimeError(f"regular input required: {resolved}")
    if expected_hash is not None and sha256(resolved) != expected_hash:
        raise RuntimeError(f"hash drift: {resolved}")
    return resolved


def exact_output_root(
    repository_root: Path,
    contract: dict[str, Any],
    process_id: str,
) -> Path:
    path = (repository_root / contract["evidenceRoot"] / process_id).absolute()
    if path.exists() or path.is_symlink():
        raise RuntimeError(f"static output root must be absent: {path}")
    parent = path.parent.resolve(strict=True)
    parent.relative_to(repository_root.resolve())
    if parent.is_symlink() or not parent.is_dir():
        raise RuntimeError("regular task-owned output parent required")
    path.mkdir(mode=0o755)
    return path


def exclusive_write(path: Path, value: Any) -> None:
    if path.parent.is_symlink() or not path.parent.is_dir():
        raise RuntimeError("output parent drift")
    descriptor = os.open(
        path,
        os.O_WRONLY | os.O_CREAT | os.O_EXCL
        | (os.O_NOFOLLOW if hasattr(os, "O_NOFOLLOW") else 0),
        0o644,
    )
    try:
        os.write(descriptor, canonical_bytes(value))
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def dependency_scan(importer: Path, lowerer: Path) -> dict[str, Any]:
    forbidden = [
        "bpy.ops.render",
        "render.filepath",
        "save_as_mainfile",
        "save_mainfile",
        "bpy.data.images",
        "import subprocess",
        "from subprocess",
        "import socket",
        "import urllib",
        "import requests",
        "eval(",
        "exec(",
        "getattr(",
        "setattr(",
    ]
    findings = []
    for path in (importer, lowerer):
        text = path.read_text(encoding="utf-8")
        for token in forbidden:
            if token in text:
                findings.append({"file": str(path), "token": token})
    if findings:
        raise RuntimeError(f"forbidden importer dependency token: {findings}")
    return {
        "files": [
            {"file": str(importer), "sha256": sha256(importer)},
            {"file": str(lowerer), "sha256": sha256(lowerer)},
        ],
        "forbiddenTokens": forbidden,
        "findings": [],
        "passed": True,
    }


def acquire_lock(path: Path) -> int:
    descriptor = os.open(
        path,
        os.O_RDWR | os.O_CREAT
        | (os.O_NOFOLLOW if hasattr(os, "O_NOFOLLOW") else 0),
        0o600,
    )
    if not stat.S_ISREG(os.fstat(descriptor).st_mode):
        os.close(descriptor)
        raise RuntimeError("regular lock file required")
    try:
        fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError as error:
        os.close(descriptor)
        raise RuntimeError("static Blender concurrency lock is busy") from error
    return descriptor


def process_group_rss_kib(process_group: int) -> int:
    result = subprocess.run(
        ["/bin/ps", "-axo", "pgid=,rss="],
        check=True,
        capture_output=True,
        text=True,
    )
    total = 0
    for line in result.stdout.splitlines():
        fields = line.split()
        if len(fields) == 2 and int(fields[0]) == process_group:
            total += int(fields[1])
    return total


def terminate_group(process_group: int) -> None:
    try:
        os.killpg(process_group, signal.SIGTERM)
    except ProcessLookupError:
        return
    time.sleep(0.2)
    try:
        os.killpg(process_group, signal.SIGKILL)
    except ProcessLookupError:
        return


def inventory(root: Path) -> dict[str, str]:
    return {
        name: sha256(exact_regular(root / name))
        for name in STATIC_CHILD_FILES
    }


def prohibited_outputs(root: Path) -> list[str]:
    prohibited_suffixes = {
        ".blend", ".png", ".jpg", ".jpeg", ".exr", ".tif", ".tiff",
        ".bmp", ".webp",
    }
    return sorted(
        str(path.relative_to(root))
        for path in root.rglob("*")
        if path.is_file() and path.suffix.lower() in prohibited_suffixes
    )


def main() -> None:
    options = arguments()
    repository_root = Path(options.repository_root).resolve(strict=True)
    source_root = (repository_root / SOURCE_RELATIVE).resolve(strict=True)
    contract_path = exact_regular(Path(options.contract))
    expected_contract = (source_root / "LOWERING-CONTRACT.json").resolve(strict=True)
    if contract_path != expected_contract:
        raise RuntimeError("exact task-local contract required")
    contract = load_json(contract_path)
    if contract["publishedBase"] != (
        "4d3428ddc62aec439859d4121814bc02928cfda6"
    ):
        raise RuntimeError("published authority base drift")
    executable = exact_regular(
        Path(contract["blender"]["executable"]),
        contract["blender"]["executableSHA256"],
    )
    importer = exact_regular(source_root / "import_v12_scene.py")
    lowerer = exact_regular(source_root / "lower_v12_scene.py")
    scan = dependency_scan(importer, lowerer)
    bound_before = {
        key: sha256(
            exact_regular(repository_root / contract[key]["file"])
        )
        for key in (
            "claim", "authority", "scene", "materials", "bridge",
            "compoundAuditTool", "analyticReplayIdentity", "compoundAudit",
            "compoundAdversaries", "compoundDisposition",
            "replayPreservation",
        )
    }
    if any(
        bound_before[key] != contract[key]["sha256"]
        for key in bound_before
    ):
        raise RuntimeError("frozen input binding drift")
    output_root = exact_output_root(
        repository_root, contract, options.process_id
    )
    command = [
        str(executable),
        "--background",
        "--factory-startup",
        "--disable-autoexec",
        "--threads",
        "1",
        "--python-exit-code",
        "1",
        "--python",
        str(importer),
        "--",
        "--repository-root",
        str(repository_root),
        "--contract",
        str(contract_path),
        "--output-root",
        str(output_root),
        "--process-id",
        options.process_id,
    ]
    lock_descriptor = acquire_lock(Path(contract["blender"]["lockFile"]))
    started = time.monotonic()
    maximum_rss_kib = 0
    process = None
    failure: dict[str, Any] | None = None
    stdout = ""
    try:
        process = subprocess.Popen(
            command,
            cwd=repository_root,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            start_new_session=True,
        )
        while process.poll() is None:
            elapsed = time.monotonic() - started
            maximum_rss_kib = max(
                maximum_rss_kib,
                process_group_rss_kib(process.pid),
            )
            if elapsed > float(
                contract["blender"]["perProcessTimeoutSeconds"]
            ):
                terminate_group(process.pid)
                failure = {
                    "reason": "per-process-timeout",
                    "elapsedSeconds": elapsed,
                }
                break
            if maximum_rss_kib > int(
                contract["blender"]["maximumProcessGroupRSSMiB"]
            ) * 1024:
                terminate_group(process.pid)
                failure = {
                    "reason": "process-group-rss-limit",
                    "maximumProcessGroupRSSKiB": maximum_rss_kib,
                }
                break
            time.sleep(0.05)
        stdout = process.communicate(timeout=5)[0] or ""
        elapsed = time.monotonic() - started
        if failure is None and process.returncode != 0:
            failure = {
                "reason": "child-nonzero-exit",
                "returnCode": process.returncode,
            }
        if failure is None and options.process_id == "static-b":
            first_provenance = load_json(
                repository_root
                / contract["evidenceRoot"]
                / "static-a"
                / "PROCESS-PROVENANCE.json"
            )
            combined = (
                float(first_provenance["elapsedSeconds"]) + elapsed
            )
            if combined > float(
                contract["blender"]["combinedTimeoutSeconds"]
            ):
                failure = {
                    "reason": "combined-process-timeout",
                    "combinedElapsedSeconds": combined,
                }
        if failure is None:
            actual_names = sorted(
                path.name for path in output_root.iterdir() if path.is_file()
            )
            if actual_names != sorted(STATIC_CHILD_FILES):
                failure = {
                    "reason": "static-child-inventory-drift",
                    "actualNames": actual_names,
                }
        prohibited = prohibited_outputs(output_root)
        if failure is None and prohibited:
            failure = {
                "reason": "prohibited-static-output",
                "files": prohibited,
            }
        bound_after = {
            key: sha256(
                exact_regular(repository_root / contract[key]["file"])
            )
            for key in bound_before
        }
        if failure is None and bound_after != bound_before:
            failure = {"reason": "frozen-input-mutation"}
        if failure is not None:
            failure_record = {
                "schema": 1,
                "task": "PLAY-027",
                "stage": contract["stage"],
                "processID": options.process_id,
                "failure": failure,
                "childCommand": command,
                "childStarted": process is not None,
                "stdoutSHA256": hashlib.sha256(
                    stdout.encode("utf-8")
                ).hexdigest(),
                "partialFiles": sorted(
                    path.name for path in output_root.iterdir()
                    if path.is_file()
                ),
                "renderInvocationCount": 0,
                "pixelFiles": prohibited,
                "sourceAuthority": False,
                "candidateReadyForIndependentReview": False,
                "productionSelected": False,
            }
            exclusive_write(output_root / "FAILURE.json", failure_record)
            raise RuntimeError(
                f"static import failed closed: {failure['reason']}"
            )
        file_inventory = inventory(output_root)
        provenance = {
            "schema": 1,
            "task": "PLAY-027",
            "stage": contract["stage"],
            "processID": options.process_id,
            "executable": str(executable),
            "executableSHA256": sha256(executable),
            "expectedVersion": contract["blender"]["version"],
            "expectedBuildHash": contract["blender"]["buildHash"],
            "childCommand": command,
            "workingDirectory": str(repository_root),
            "returnCode": process.returncode,
            "elapsedSeconds": round(elapsed, 6),
            "maximumProcessGroupRSSKiB": maximum_rss_kib,
            "maximumProcessGroupRSSMiB": round(
                maximum_rss_kib / 1024.0, 6
            ),
            "monitorSampleMaximumSeconds": 0.05,
            "exclusiveLockFile": contract["blender"]["lockFile"],
            "dependencyScan": scan,
            "inputHashesBefore": bound_before,
            "inputHashesAfter": bound_after,
            "childOutputInventory": file_inventory,
            "stdoutSHA256": hashlib.sha256(
                stdout.encode("utf-8")
            ).hexdigest(),
            "renderInvocationCount": 0,
            "pixelFiles": [],
            "blendFiles": [],
            "sourceAuthority": False,
            "candidateReadyForIndependentReview": False,
            "productionSelected": False,
        }
        exclusive_write(output_root / "PROCESS-PROVENANCE.json", provenance)
        print(json.dumps({
            "processID": options.process_id,
            "elapsedSeconds": provenance["elapsedSeconds"],
            "maximumProcessGroupRSSMiB": provenance[
                "maximumProcessGroupRSSMiB"
            ],
            "childOutputFiles": len(file_inventory),
            "validationPassed": True,
        }, sort_keys=True))
    finally:
        fcntl.flock(lock_descriptor, fcntl.LOCK_UN)
        os.close(lock_descriptor)


if __name__ == "__main__":
    main()
