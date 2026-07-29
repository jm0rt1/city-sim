#!/usr/bin/env python3
"""Zero-pixel validation for the PLAY-079 launch-bound preparation CLI."""

from __future__ import annotations

import argparse
import ast
import hashlib
import importlib.util
import json
import pathlib
import subprocess
import sys
from typing import Any

import east_output_safety as output_safety


SOURCE_ROOT = pathlib.Path(__file__).resolve().parent
REPOSITORY_ROOT = SOURCE_ROOT.parents[5]
CLI_PATH = SOURCE_ROOT / "prepare_launch_bound.py"
FIXTURE_ROOT = SOURCE_ROOT / "fixtures"
FIXTURE_BUNDLE = FIXTURE_ROOT / "DRY-STRUCTURAL-BUNDLE.json"
APPEARANCE_FIXTURE = FIXTURE_ROOT / "NONPRODUCTION-APPEARANCE-LOCK.json"
PROFILE_FIXTURE = FIXTURE_ROOT / "NONPRODUCTION-SOURCE-PRODUCTION-PROFILE.json"
INVALID_PROFILE_FIXTURE = FIXTURE_ROOT / "INVALID-SOURCE-PRODUCTION-PROFILE.json"
REVIEWED_CANDIDATE = "3ca37996953230b7255f6a22ac1f977c99e56e03"
PIXEL_EXTENSIONS = {
    ".bmp",
    ".exr",
    ".gif",
    ".jpeg",
    ".jpg",
    ".png",
    ".tif",
    ".tiff",
    ".webp",
}


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def sha256(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_cli() -> Any:
    spec = importlib.util.spec_from_file_location("play079_launch_preparation_cli", CLI_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("could not load launch preparation CLI")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def invoke(arguments: list[str]) -> tuple[int, dict[str, Any]]:
    result = subprocess.run(
        [sys.executable, "-B", str(CLI_PATH), *arguments],
        cwd=REPOSITORY_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.stderr:
        raise RuntimeError(f"unexpected CLI stderr: {result.stderr}")
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError(f"invalid CLI JSON: {result.stdout}") from error
    return result.returncode, payload


def expect_rejection(callable_value: Any, expected_code: str) -> dict[str, Any]:
    cli = load_cli()
    try:
        callable_value(cli)
    except cli.PreparationRejected as rejection:
        if rejection.code != expected_code:
            raise RuntimeError(
                f"expected {expected_code}, got {rejection.code}: {rejection.detail}"
            ) from rejection
        return {
            "result": "REJECTED",
            "code": rejection.code,
            "detail": rejection.detail,
            "filesWritten": 0,
            "blenderProcessLaunches": 0,
            "blenderRenderApiCalls": 0,
            "pixelFiles": 0,
        }
    raise RuntimeError(f"expected rejection {expected_code}")


def final_artifact_paths() -> tuple[pathlib.Path, pathlib.Path]:
    contract = json.loads((SOURCE_ROOT / "RUNNER-CONTRACT.json").read_text(encoding="utf-8"))
    return (
        REPOSITORY_ROOT / contract["sourceStage"]["guardReceiptPath"],
        REPOSITORY_ROOT / contract["sourceStage"]["handoffOutputPath"],
    )


def pixel_inventory() -> list[str]:
    evidence = (
        REPOSITORY_ROOT
        / "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01"
    )
    return sorted(
        str(path.relative_to(REPOSITORY_ROOT))
        for root in (SOURCE_ROOT, evidence)
        for path in root.rglob("*")
        if path.is_file() and path.suffix.lower() in PIXEL_EXTENSIONS
    )


def static_proof() -> dict[str, Any]:
    source = CLI_PATH.read_text(encoding="utf-8")
    tree = ast.parse(source)
    bpy_imports = 0
    launch_calls = 0
    write_calls: list[int] = []
    production_validation_line: int | None = None
    for node in ast.walk(tree):
        if isinstance(node, (ast.Import, ast.ImportFrom)):
            bpy_imports += sum(
                alias.name == "bpy" or alias.name.startswith("bpy.")
                for alias in node.names
            )
        if isinstance(node, ast.Call):
            if isinstance(node.func, ast.Name):
                if node.func.id in {"launch_blender", "blender_worker"}:
                    launch_calls += 1
                if node.func.id == "write_exclusive_atomic":
                    write_calls.append(node.lineno)
                if node.func.id == "validate_production_authorities":
                    production_validation_line = node.lineno
    if bpy_imports or launch_calls or "bpy.ops.render" in source:
        raise RuntimeError("launch preparation CLI contains a Blender/render path")
    if production_validation_line is None or len(write_calls) != 2:
        raise RuntimeError("production validation/write ordering could not be proved")
    if production_validation_line >= min(write_calls):
        raise RuntimeError("launch artifacts may be written before authority validation")
    return {
        "result": "PASS",
        "bpyImports": bpy_imports,
        "blenderLaunchCalls": launch_calls,
        "renderApiReferences": source.count("bpy.ops.render"),
        "productionAuthorityValidationLine": production_validation_line,
        "exclusiveAtomicWriteLines": sorted(write_calls),
        "authorityValidationPrecedesWrites": True,
    }


def build_proof() -> dict[str, Any]:
    receipt_path, handoff_path = final_artifact_paths()
    if receipt_path.exists() or handoff_path.exists():
        raise RuntimeError("launch artifacts must be absent before zero-pixel CLI validation")

    missing_profile_status, missing_profile = invoke(["--mode", "prepare"])
    if (
        missing_profile_status != 2
        or missing_profile.get("code") != "missing_source_production_profile_input"
    ):
        raise RuntimeError(f"missing-profile guard failed: {missing_profile}")

    missing_lock_status, missing_lock = invoke(
        [
            "--mode",
            "prepare",
            "--source-production-profile",
            str(PROFILE_FIXTURE.relative_to(REPOSITORY_ROOT)),
            "--source-profile-commit",
            REVIEWED_CANDIDATE,
            "--source-profile-sha256",
            sha256(PROFILE_FIXTURE),
            "--cell-content-commit",
            REVIEWED_CANDIDATE,
        ]
    )
    if missing_lock_status != 2 or missing_lock.get("code") != "missing_appearance_lock_input":
        raise RuntimeError(f"missing-lock guard failed: {missing_lock}")

    outside_status, outside = invoke(
        [
            "--mode",
            "prepare",
            "--appearance-lock",
            str(APPEARANCE_FIXTURE.relative_to(REPOSITORY_ROOT)),
            "--source-production-profile",
            str(PROFILE_FIXTURE.relative_to(REPOSITORY_ROOT)),
            "--source-profile-commit",
            REVIEWED_CANDIDATE,
            "--source-profile-sha256",
            sha256(PROFILE_FIXTURE),
            "--cell-content-commit",
            REVIEWED_CANDIDATE,
        ]
    )
    if (
        outside_status != 2
        or outside.get("code") != "source_profile_outside_integration_authority_root"
    ):
        raise RuntimeError(f"outside-root guard failed: {outside}")

    mismatch = expect_rejection(
        lambda cli: cli.validate_file_hash(
            APPEARANCE_FIXTURE,
            "0" * 64,
            "appearance_lock",
        ),
        "appearance_lock_sha256_mismatch",
    )
    stale = expect_rejection(
        lambda cli: cli.require_commit("0" * 40, "source_profile"),
        "source_profile_missing_commit",
    )
    invalid_profile = expect_rejection(
        lambda cli: cli.validate_profile_shape(
            cli.load_json(INVALID_PROFILE_FIXTURE, "fixture_source_profile_invalid_json")
        ),
        "source_profile_schema_invalid",
    )

    dry_status, dry = invoke(
        [
            "--mode",
            "dry-structural",
            "--fixture-bundle",
            str(FIXTURE_BUNDLE.relative_to(REPOSITORY_ROOT)),
            "--cell-content-commit",
            REVIEWED_CANDIDATE,
        ]
    )
    if dry_status != 0 or dry.get("result") != "PASS":
        raise RuntimeError(f"dry structural fixture failed: {dry}")
    if dry.get("filesWritten") != 0 or not dry.get("fixtureOnly"):
        raise RuntimeError(f"dry structural fixture wrote files: {dry}")

    if receipt_path.exists() or handoff_path.exists():
        raise RuntimeError("zero-pixel CLI validation created launch artifacts")
    pixels = pixel_inventory()
    if pixels:
        raise RuntimeError(f"zero-pixel CLI validation found pixel files: {pixels}")
    return {
        "schema": "citysim.world-art.launch-bound-cli-validation.v1",
        "taskId": "PLAY-079",
        "direction": "east",
        "branch": "codex/citysim-world-art-east",
        "reviewedCandidate": REVIEWED_CANDIDATE,
        "result": "PASS",
        "static": static_proof(),
        "negativeTests": {
            "missingSourceProductionProfile": missing_profile,
            "missingAppearanceLock": missing_lock,
            "outsideGovernedAuthorityRoot": outside,
            "mismatchedSha256": mismatch,
            "staleOrMissingCommit": stale,
            "schemaInvalidProfile": invalid_profile,
        },
        "dryStructuralFixture": dry,
        "launchArtifacts": {
            "guardReceiptPath": str(receipt_path.relative_to(REPOSITORY_ROOT)),
            "handoffPath": str(handoff_path.relative_to(REPOSITORY_ROOT)),
            "filesWritten": 0,
        },
        "invocations": {
            "blenderProcessLaunches": 0,
            "blenderRenderApiCalls": 0,
            "imageGenInvocations": 0,
            "normalizerInvocations": 0,
            "contactSheetInvocations": 0,
            "renderInvocations": 0,
        },
        "pixelFiles": {
            "count": 0,
            "paths": [],
        },
        "pixelValidation": {
            "rgba": "not_run",
            "literal192": "not_run",
            "abcIdentity": "not_run",
            "normalization": "not_run",
        },
        "sourceReady": False,
        "productionSelected": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=pathlib.Path)
    args = parser.parse_args()
    proof = build_proof()
    payload = canonical_bytes(proof)
    if args.output:
        output_safety.write_bytes_exclusive(
            args.output,
            payload,
            "validation",
        )
    sys.stdout.buffer.write(payload)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
