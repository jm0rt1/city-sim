#!/usr/bin/env python3
"""Validate the PLAY-079 East runner without launching Blender or reading pixels."""

from __future__ import annotations

import argparse
import ast
import hashlib
import importlib.util
import json
import pathlib
import sys
import tempfile
from typing import Any


SOURCE_ROOT = pathlib.Path(__file__).resolve().parent
REPOSITORY_ROOT = SOURCE_ROOT.parents[5]
CONTRACT_PATH = SOURCE_ROOT / "RUNNER-CONTRACT.json"
DRIVER_PATH = SOURCE_ROOT / "run_production.py"
PIXEL_VALIDATOR_PATH = SOURCE_ROOT / "validate_source_outputs.py"
SCHEMA_PATH = (
    REPOSITORY_ROOT
    / "docs/production/evidence/INTEGRATION/industrial-l04-prelock-runner-handoff-schema-v1.json"
)
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


def load_driver() -> Any:
    spec = importlib.util.spec_from_file_location("play079_east_runner", DRIVER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("could not load direction-local driver")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def static_driver_proof(driver: Any) -> dict[str, Any]:
    source = DRIVER_PATH.read_text(encoding="utf-8")
    tree = ast.parse(source)
    top_level_bpy_imports = 0
    worker_guard_line: int | None = None
    worker_bpy_import_line: int | None = None
    for node in tree.body:
        if isinstance(node, (ast.Import, ast.ImportFrom)):
            names = [alias.name for alias in node.names]
            top_level_bpy_imports += sum(name == "bpy" or name.startswith("bpy.") for name in names)
        if isinstance(node, ast.FunctionDef) and node.name == "blender_worker":
            for child in ast.walk(node):
                if isinstance(child, ast.Call) and isinstance(child.func, ast.Name):
                    if child.func.id == "validate_appearance_lock":
                        worker_guard_line = child.lineno
                if isinstance(child, (ast.Import, ast.ImportFrom)):
                    names = [alias.name for alias in child.names]
                    if any(name == "bpy" or name.startswith("bpy.") for name in names):
                        worker_bpy_import_line = child.lineno
    render_references = source.count("bpy.ops.render.render(")
    if top_level_bpy_imports != 0:
        raise RuntimeError("bpy must not be imported before the render guard")
    if worker_guard_line is None or worker_bpy_import_line is None:
        raise RuntimeError("worker guard/import ordering could not be proved")
    if worker_guard_line >= worker_bpy_import_line:
        raise RuntimeError("worker imports bpy before validating the appearance lock")
    if render_references != 2:
        raise RuntimeError(f"expected two guarded future render references, found {render_references}")

    contract = driver.load_json(CONTRACT_PATH)
    first = driver.validate_contract(contract)
    second = driver.validate_contract(contract)
    if driver.canonical_bytes(first) != driver.canonical_bytes(second):
        raise RuntimeError("repeat static validation identity failed")
    return {
        "result": "PASS",
        "topLevelBpyImports": top_level_bpy_imports,
        "workerAppearanceGuardLine": worker_guard_line,
        "workerBpyImportLine": worker_bpy_import_line,
        "guardPrecedesBpyImport": True,
        "guardedFutureRenderApiReferences": render_references,
        "repeatIdentityPass": True,
        "frozenInputCount": len(first["frozenHashes"]),
    }


def guard_rejection(driver: Any, appearance_lock: pathlib.Path | None) -> dict[str, Any]:
    launches = 0

    def forbidden_launcher(*_args: Any, **_kwargs: Any) -> int:
        nonlocal launches
        launches += 1
        raise RuntimeError("guard allowed a Blender launch")

    try:
        driver.execute("A", appearance_lock, launcher=forbidden_launcher)
    except driver.GuardRejected as rejection:
        result = {
            "result": "REJECTED",
            "stage": "before_renderer_launch",
            "code": rejection.code,
            "detail": rejection.detail,
            "blenderProcessLaunches": launches,
            "blenderRenderApiCalls": 0,
            "imageGenInvocations": 0,
            "normalizerInvocations": 0,
            "contactSheetInvocations": 0,
            "renderInvocations": 0,
            "pixelFiles": 0,
        }
    else:
        raise RuntimeError("render guard did not reject")
    if launches != 0:
        raise RuntimeError("Blender launcher was reached")
    return result


def pixel_inventory() -> list[str]:
    roots = [
        SOURCE_ROOT,
        REPOSITORY_ROOT / "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01",
    ]
    return sorted(
        str(path.relative_to(REPOSITORY_ROOT))
        for root in roots
        if root.exists()
        for path in root.rglob("*")
        if path.is_file() and path.suffix.lower() in PIXEL_EXTENSIONS
    )


def validate_handoff(path: pathlib.Path) -> dict[str, Any]:
    import jsonschema

    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    handoff = json.loads(path.read_text(encoding="utf-8"))
    jsonschema.Draft202012Validator(schema).validate(handoff)
    expected_hashes = {
        handoff["runner"]["contractPath"]: handoff["runner"]["contractSha256"],
        handoff["runner"]["driverPath"]: handoff["runner"]["driverSha256"],
        **handoff["runner"]["validatorHashes"],
    }
    for relative, expected in expected_hashes.items():
        actual = sha256(REPOSITORY_ROOT / relative)
        if actual != expected:
            raise RuntimeError(f"handoff hash mismatch for {relative}: {actual}")
    return {
        "result": "PASS",
        "schemaVersion": handoff["schemaVersion"],
        "schemaSha256": sha256(SCHEMA_PATH),
        "handoffPath": str(path.relative_to(REPOSITORY_ROOT)),
        "handoffSha256": sha256(path),
        "runnerFileCount": len(expected_hashes),
    }


def build_proof(handoff_path: pathlib.Path | None) -> dict[str, Any]:
    driver = load_driver()
    static = static_driver_proof(driver)
    missing = guard_rejection(driver, None)
    with tempfile.TemporaryDirectory(prefix="play079-east-wrong-lock-") as temporary:
        wrong_path = pathlib.Path(temporary) / "WRONG-LOCK.json"
        wrong_path.write_text('{"not":"an appearance lock"}\\n', encoding="utf-8")
        wrong = guard_rejection(driver, wrong_path)
    if missing["code"] != "missing_appearance_lock":
        raise RuntimeError(f"unexpected missing-lock code: {missing['code']}")
    if wrong["code"] != "unpublished_or_wrong_appearance_lock":
        raise RuntimeError(f"unexpected wrong-lock code: {wrong['code']}")
    pixels = pixel_inventory()
    if pixels:
        raise RuntimeError(f"pre-lock pixel files are forbidden: {pixels}")

    result: dict[str, Any] = {
        "schema": "citysim.world-art.prelock-runner-validation.v1",
        "taskId": "PLAY-079",
        "direction": "east",
        "branch": "codex/citysim-world-art-east",
        "baselineCommit": "30af21b5a3cbabb26c415f76d8ce35934dcc5082",
        "result": "PASS",
        "static": static,
        "missingLock": missing,
        "wrongLock": wrong,
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
        "runnerHashes": {
            str(CONTRACT_PATH.relative_to(REPOSITORY_ROOT)): sha256(CONTRACT_PATH),
            str(DRIVER_PATH.relative_to(REPOSITORY_ROOT)): sha256(DRIVER_PATH),
            str(pathlib.Path(__file__).resolve().relative_to(REPOSITORY_ROOT)): sha256(
                pathlib.Path(__file__).resolve()
            ),
            str(PIXEL_VALIDATOR_PATH.relative_to(REPOSITORY_ROOT)): sha256(PIXEL_VALIDATOR_PATH),
        },
    }
    if handoff_path is not None:
        result["handoffValidation"] = validate_handoff(handoff_path.resolve())
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--handoff", type=pathlib.Path)
    parser.add_argument("--output", type=pathlib.Path)
    args = parser.parse_args()
    proof = build_proof(args.handoff)
    payload = canonical_bytes(proof)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_bytes(payload)
    sys.stdout.buffer.write(payload)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
