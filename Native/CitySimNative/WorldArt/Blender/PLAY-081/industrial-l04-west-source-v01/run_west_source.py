#!/usr/bin/env python3
"""Hard-guarded PLAY-081 West source runner.

The system-Python entry point validates every frozen input and the complete
Integration appearance-lock binding before it can launch Blender. It never
imports Blender's Python API. In the pre-lock state, A/B/C always stop with a
machine-readable rejection before ``subprocess.run`` can reach Blender.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


DEFAULT_CONTRACT = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-081/"
    "industrial-l04-west-source-v01/RUNNER-CONTRACT.json"
)
REQUIRED_LOCK_FIELDS = (
    "documentPath",
    "commit",
    "documentSha256",
    "northProcessASourceSha256",
    "northProcessADecodedRgbaSha256",
)
class ContractError(RuntimeError):
    """Raised when immutable runner inputs or structure are invalid."""


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text())
    if not isinstance(value, dict):
        raise ContractError(f"expected JSON object: {path}")
    return value


def repository_path(root: Path, relative: str) -> Path:
    if not relative or Path(relative).is_absolute():
        raise ContractError(f"path must be repository-relative: {relative!r}")
    resolved = (root / relative).resolve()
    try:
        resolved.relative_to(root)
    except ValueError as error:
        raise ContractError(f"path escapes repository: {relative}") from error
    return resolved


def hash_binding_errors(
    root: Path, name: str, binding: dict[str, Any]
) -> list[str]:
    path_value = binding.get("path")
    expected = binding.get("sha256")
    if not isinstance(path_value, str) or not isinstance(expected, str):
        return [f"{name}:invalid-binding"]
    try:
        path = repository_path(root, path_value)
    except ContractError:
        return [f"{name}:invalid-path"]
    if not path.is_file():
        return [f"{name}:missing"]
    if sha256(path) != expected:
        return [f"{name}:sha256-mismatch"]
    return []


def frozen_input_errors(root: Path, contract: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    expected_scalars = {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "branch": "codex/citysim-world-art-west",
        "baselineCommit": "30af21b5a3cbabb26c415f76d8ce35934dcc5082",
        "sourceReady": False,
        "productionSelected": False,
    }
    for key, expected in expected_scalars.items():
        if contract.get(key) != expected:
            errors.append(f"contract:{key}")

    for name in ("authority", "handoffSchema", "governingContract"):
        value = contract.get(name)
        if not isinstance(value, dict):
            errors.append(f"{name}:missing-binding")
        else:
            errors.extend(hash_binding_errors(root, name, value))

    predesign = contract.get("acceptedPredesign")
    if not isinstance(predesign, dict):
        errors.append("acceptedPredesign:missing")
    else:
        for name in (
            "handoff",
            "scene",
            "materials",
            "validator",
            "actualCameraProofScript",
            "staticProof",
            "actualCameraProof",
            "repeatIdentity",
        ):
            binding = predesign.get(name)
            if not isinstance(binding, dict):
                errors.append(f"acceptedPredesign.{name}:missing-binding")
            else:
                errors.extend(
                    hash_binding_errors(root, f"acceptedPredesign.{name}", binding)
                )

    invariants = contract.get("invariants", {})
    registration = invariants.get("registration", {})
    camera = invariants.get("camera", {})
    light = invariants.get("lightAndContact", {})
    pipeline = invariants.get("renderPipeline", {})
    exact_invariants = (
        (invariants.get("orientationTransform"), "none", "orientation-transform"),
        (registration.get("frontageEdge"), "west", "frontage-edge"),
        (
            registration.get("frontageSocketWorldXYZ"),
            [-28, 0, 0],
            "frontage-socket",
        ),
        (
            registration.get("groundPivotWorldXYZ"),
            [28, 0, 28],
            "ground-pivot",
        ),
        (
            camera.get("renderViewportPixels"),
            [1536, 1024],
            "source-resolution",
        ),
        (
            camera.get("literalViewportPixels"),
            [192, 128],
            "literal-resolution",
        ),
        (light.get("keyDirection"), "northwest", "key-direction"),
        (light.get("contactDirection"), "southeast", "contact-direction"),
        (pipeline.get("engine"), "CYCLES", "render-engine"),
        (pipeline.get("device"), "CPU", "cycles-device"),
        (pipeline.get("threads"), 1, "render-threads"),
        (pipeline.get("samples"), 64, "render-samples"),
        (pipeline.get("adaptiveSampling"), False, "adaptive-sampling"),
        (pipeline.get("denoising"), False, "denoising"),
        (pipeline.get("motionBlur"), False, "motion-blur"),
        (pipeline.get("transparentFilm"), True, "transparent-film"),
    )
    for actual, expected, name in exact_invariants:
        if actual != expected:
            errors.append(f"invariant:{name}")

    implementation = contract.get("runnerImplementation", {})
    blender_script = implementation.get("blenderScriptPath")
    if not isinstance(blender_script, str):
        errors.append("runnerImplementation:blender-script-path")
    else:
        try:
            if not repository_path(root, blender_script).is_file():
                errors.append("runnerImplementation:blender-script-missing")
        except ContractError:
            errors.append("runnerImplementation:blender-script-invalid")

    counts = contract.get("invocationCounts", {})
    if not isinstance(counts, dict) or any(value != 0 for value in counts.values()):
        errors.append("invocation-counts:nonzero")
    return sorted(set(errors))


def _validate_lock_document(
    lock_document: dict[str, Any], appearance: dict[str, Any]
) -> list[str]:
    errors: list[str] = []
    binding = lock_document.get("appearanceLockBinding")
    if not isinstance(binding, dict):
        return ["appearance-lock:binding-missing"]
    expected = {
        "commit": appearance["commit"],
        "northProcessASourceSha256": appearance["northProcessASourceSha256"],
        "northProcessADecodedRgbaSha256": appearance[
            "northProcessADecodedRgbaSha256"
        ],
    }
    for key, value in expected.items():
        if binding.get(key) != value:
            errors.append(f"appearance-lock:{key}-binding-mismatch")
    return errors


def _validate_material_mapping(
    mapping: dict[str, Any],
    appearance_sha256: str,
    required_roles: set[str],
) -> list[str]:
    errors: list[str] = []
    if mapping.get("schemaVersion") != 1:
        errors.append("locked-materials:schema-version")
    if mapping.get("direction") != "west":
        errors.append("locked-materials:direction")
    if mapping.get("appearanceLockSha256") != appearance_sha256:
        errors.append("locked-materials:appearance-lock-binding")
    roles = mapping.get("roles")
    if not isinstance(roles, dict):
        return errors + ["locked-materials:roles-missing"]
    if set(roles) != required_roles:
        errors.append("locked-materials:role-set")
    for name, role in roles.items():
        if not isinstance(role, dict):
            errors.append(f"locked-materials:{name}:invalid")
            continue
        color = role.get("baseColorSrgb")
        if (
            not isinstance(color, list)
            or len(color) != 4
            or any(not isinstance(value, (int, float)) for value in color)
        ):
            errors.append(f"locked-materials:{name}:base-color")
        for key in ("roughness", "metallic"):
            value = role.get(key)
            if not isinstance(value, (int, float)) or not 0 <= value <= 1:
                errors.append(f"locked-materials:{name}:{key}")
    return errors


def evaluate_render_guard(
    root: Path, contract: dict[str, Any], mode: str
) -> dict[str, Any]:
    """Return a deterministic pre-launch decision without launching Blender."""
    errors = frozen_input_errors(root, contract)
    appearance = contract.get("appearanceLock")
    if not isinstance(appearance, dict):
        errors.append("appearance-lock:missing-object")
        appearance = {}
    missing_fields = [
        field for field in REQUIRED_LOCK_FIELDS if not appearance.get(field)
    ]
    for field in ("appearanceLockCommit", "appearanceLockSha256"):
        if not contract.get(field):
            missing_fields.append(field)
    material_binding = contract.get("lockedMaterialMapping")
    if not isinstance(material_binding, dict):
        material_binding = {}
        errors.append("locked-materials:missing-object")
    for field in ("path", "sha256"):
        if not material_binding.get(field):
            missing_fields.append(f"lockedMaterialMapping.{field}")
    if contract.get("state") != "ready_for_source_render":
        missing_fields.append("state.ready_for_source_render")
    if missing_fields:
        errors.append("appearance-lock:missing")

    if not missing_fields:
        if contract["appearanceLockCommit"] != appearance["commit"]:
            errors.append("appearance-lock:commit-alias-mismatch")
        if contract["appearanceLockSha256"] != appearance["documentSha256"]:
            errors.append("appearance-lock:sha256-alias-mismatch")
        try:
            lock_path = repository_path(root, appearance["documentPath"])
            if not lock_path.is_file():
                errors.append("appearance-lock:document-missing")
            elif sha256(lock_path) != appearance["documentSha256"]:
                errors.append("appearance-lock:document-sha256-mismatch")
            else:
                errors.extend(
                    _validate_lock_document(load_json(lock_path), appearance)
                )
        except (ContractError, OSError, json.JSONDecodeError):
            errors.append("appearance-lock:document-invalid")

        try:
            mapping_path = repository_path(root, material_binding["path"])
            if not mapping_path.is_file():
                errors.append("locked-materials:file-missing")
            elif sha256(mapping_path) != material_binding["sha256"]:
                errors.append("locked-materials:sha256-mismatch")
            else:
                predesign_materials = load_json(
                    repository_path(
                        root, contract["acceptedPredesign"]["materials"]["path"]
                    )
                )
                errors.extend(
                    _validate_material_mapping(
                        load_json(mapping_path),
                        appearance["documentSha256"],
                        set(predesign_materials["roles"]),
                    )
                )
        except (ContractError, OSError, json.JSONDecodeError, KeyError):
            errors.append("locked-materials:file-invalid")

    process = contract.get("outputInventory", {}).get("processes", {}).get(mode)
    if not isinstance(process, dict):
        errors.append("output:process-missing")
    else:
        expected_directory = (
            "docs/production/evidence/PLAY-081/"
            f"industrial-l04-west-source-v01/process-{mode}"
        )
        if process.get("directory") != expected_directory:
            errors.append("output:non-deterministic-directory")

    return {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "mode": mode,
        "decision": "reject" if errors else "allow",
        "rejectionStage": "before_renderer_launch",
        "reasonCodes": sorted(set(errors)),
        "blenderProcessLaunches": 0,
        "blenderRenderApiCalls": 0,
        "imageGenInvocations": 0,
        "normalizerInvocations": 0,
        "contactSheetInvocations": 0,
        "renderInvocations": 0,
        "pixelFiles": 0,
    }


def _verify_lock_commit_ancestry(root: Path, commit: str) -> None:
    object_check = subprocess.run(
        ["git", "cat-file", "-e", f"{commit}^{{commit}}"],
        cwd=root,
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if object_check.returncode:
        raise ContractError("appearance-lock commit is not a local commit")
    ancestry = subprocess.run(
        ["git", "merge-base", "--is-ancestor", commit, "HEAD"],
        cwd=root,
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if ancestry.returncode:
        raise ContractError("appearance-lock commit is not an ancestor of HEAD")


def launch_blender(
    root: Path, contract_path: Path, contract: dict[str, Any], mode: str
) -> int:
    """Launch Blender only after ``evaluate_render_guard`` returned allow."""
    appearance = contract["appearanceLock"]
    _verify_lock_commit_ancestry(root, appearance["commit"])
    pipeline = contract["invariants"]["renderPipeline"]
    executable = Path(pipeline["blenderExecutable"])
    if not executable.is_file() or sha256(executable) != pipeline["blenderExecutableSha256"]:
        raise ContractError("Blender executable fingerprint mismatch")
    script = repository_path(
        root, contract["runnerImplementation"]["blenderScriptPath"]
    )
    mapping = repository_path(root, contract["lockedMaterialMapping"]["path"])
    output = repository_path(
        root, contract["outputInventory"]["processes"][mode]["directory"]
    )
    if output.exists():
        raise ContractError(f"refusing to overwrite existing output: {output}")
    command = [
        str(executable),
        *pipeline["startupArguments"],
        "--python",
        str(script),
        "--",
        "--repository-root",
        str(root),
        "--runner-contract",
        str(contract_path.relative_to(root)),
        "--locked-materials",
        str(mapping.relative_to(root)),
        "--process-id",
        mode,
        "--output-directory",
        str(output.relative_to(root)),
    ]
    completed = subprocess.run(command, cwd=root, check=False)
    return completed.returncode


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", default=DEFAULT_CONTRACT)
    parser.add_argument("--mode", required=True, choices=("validate", "A", "B", "C"))
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = Path(args.repository_root).resolve()
    contract_path = repository_path(root, args.contract)
    contract = load_json(contract_path)
    if args.mode == "validate":
        errors = frozen_input_errors(root, contract)
        result = {
            "schemaVersion": 1,
            "taskId": "PLAY-081",
            "direction": "west",
            "mode": "validate",
            "passed": not errors,
            "errors": errors,
            "state": contract.get("state"),
            "renderInvocations": 0,
            "pixelFiles": 0,
        }
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0 if not errors else 1

    decision = evaluate_render_guard(root, contract, args.mode)
    if decision["decision"] != "allow":
        print(json.dumps(decision, indent=2, sort_keys=True))
        return 3
    try:
        return launch_blender(root, contract_path, contract, args.mode)
    except ContractError as error:
        rejected = copy.deepcopy(decision)
        rejected["decision"] = "reject"
        rejected["reasonCodes"] = [f"prelaunch:{error}"]
        print(json.dumps(rejected, indent=2, sort_keys=True))
        return 3


if __name__ == "__main__":
    raise SystemExit(main())
