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

import east_output_safety as output_safety


SOURCE_ROOT = pathlib.Path(__file__).resolve().parent
REPOSITORY_ROOT = SOURCE_ROOT.parents[5]
CONTRACT_PATH = SOURCE_ROOT / "RUNNER-CONTRACT.json"
DRIVER_PATH = SOURCE_ROOT / "run_production.py"
PIXEL_VALIDATOR_PATH = SOURCE_ROOT / "validate_source_outputs.py"
PRELOCK_SCHEMA_PATH = (
    REPOSITORY_ROOT
    / "docs/production/evidence/INTEGRATION/industrial-l04-prelock-runner-handoff-schema-v1.json"
)
SOURCE_STAGE_SCHEMA_V2_PATH = (
    REPOSITORY_ROOT
    / "docs/production/evidence/INTEGRATION/industrial-l04-source-stage-handoff-schema-v2.json"
)
SEMANTIC_VALIDATOR_PATH = (
    REPOSITORY_ROOT
    / "Native/CitySimNative/WorldArt/Shared/validate_source_stage_handoff_v2.py"
)
SOURCE_STAGE_SCHEMA_V2_SHA256 = (
    "93efe9ca6d000a2d145098f722338c8e85829d6de6724c3f231a93c06eadf3d7"
)
SEMANTIC_VALIDATOR_SHA256 = (
    "7a0613af9998a222a583a70930ce3afc5ec1902793f03201f899a2bb4129f340"
)
PUBLISHED_BASELINE = "9950906e8dbbc3cf48a0dc5b05e9a7d38b7a76d8"
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


def load_semantic_validator() -> Any:
    if sha256(SEMANTIC_VALIDATOR_PATH) != SEMANTIC_VALIDATOR_SHA256:
        raise RuntimeError("shared semantic-validator authority drifted")
    shared_root = str(SEMANTIC_VALIDATOR_PATH.parent)
    if shared_root not in sys.path:
        sys.path.insert(0, shared_root)
    spec = importlib.util.spec_from_file_location(
        "citysim_source_stage_semantic_v2",
        SEMANTIC_VALIDATOR_PATH,
    )
    if spec is None or spec.loader is None:
        raise RuntimeError("could not load shared semantic validator")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def static_driver_proof(driver: Any) -> dict[str, Any]:
    source = DRIVER_PATH.read_text(encoding="utf-8")
    tree = ast.parse(source)
    top_level_bpy_imports = 0
    worker_source_stage_guard_line: int | None = None
    worker_bridge_guard_line: int | None = None
    worker_bpy_import_line: int | None = None
    for node in tree.body:
        if isinstance(node, (ast.Import, ast.ImportFrom)):
            names = [alias.name for alias in node.names]
            top_level_bpy_imports += sum(name == "bpy" or name.startswith("bpy.") for name in names)
        if isinstance(node, ast.FunctionDef) and node.name == "blender_worker":
            for child in ast.walk(node):
                if isinstance(child, ast.Call) and isinstance(child.func, ast.Name):
                    if child.func.id == "validate_source_stage_authority":
                        worker_source_stage_guard_line = child.lineno
                    if child.func.id == "validate_coordinate_bridge":
                        worker_bridge_guard_line = child.lineno
                if isinstance(child, (ast.Import, ast.ImportFrom)):
                    names = [alias.name for alias in child.names]
                    if any(name == "bpy" or name.startswith("bpy.") for name in names):
                        worker_bpy_import_line = child.lineno
    render_references = source.count("bpy.ops.render.render(")
    if top_level_bpy_imports != 0:
        raise RuntimeError("bpy must not be imported before the render guard")
    if (
        worker_source_stage_guard_line is None
        or worker_bridge_guard_line is None
        or worker_bpy_import_line is None
    ):
        raise RuntimeError("worker guard/import ordering could not be proved")
    if max(worker_source_stage_guard_line, worker_bridge_guard_line) >= worker_bpy_import_line:
        raise RuntimeError("worker imports bpy before validating both hard guards")
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
        "workerSourceStageAuthorityGuardLine": worker_source_stage_guard_line,
        "workerCoordinateBridgeGuardLine": worker_bridge_guard_line,
        "workerBpyImportLine": worker_bpy_import_line,
        "bothGuardsPrecedeBpyImport": True,
        "guardedFutureRenderApiReferences": render_references,
        "repeatIdentityPass": True,
        "frozenInputCount": len(first["frozenHashes"]),
    }


def guard_rejection(
    driver: Any,
    appearance_lock: pathlib.Path | None,
    *,
    production_entrypoint: bool,
) -> dict[str, Any]:
    launches = 0

    def forbidden_launcher(*_args: Any, **_kwargs: Any) -> int:
        nonlocal launches
        launches += 1
        raise RuntimeError("guard allowed a Blender launch")

    try:
        if production_entrypoint:
            driver.execute("A", appearance_lock, launcher=forbidden_launcher)
        else:
            contract = driver.load_json(CONTRACT_PATH)
            driver.validate_appearance_authority(contract, appearance_lock)
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


def coordinate_bridge_adoption(driver: Any) -> dict[str, Any]:
    contract = driver.load_json(CONTRACT_PATH)
    driver.validate_contract(contract)
    validated = driver.validate_coordinate_bridge(contract)
    binding = validated["binding"]
    mapping = validated["mapping"]
    east = mapping["directions"]["east"]
    return {
        "result": "PASS",
        "state": "validated_v06",
        "acceptedSourceCandidateCommit": contract["invariants"]["coordinateBridge"][
            "acceptedSourceCandidateCommit"
        ],
        "mappingContractPath": binding["mappingContractPath"],
        "mappingContractSha256": binding["mappingContractSha256"],
        "basis": mapping["basis"],
        "canonicalCitySimEastSocket": east["socketCitySim"],
        "blenderNativeEastSocket": east["socketBlender"],
        "sourcePixelEastSocket": east["socketSource"],
        "blenderContactCornerOrder": binding["blenderContactCornerOrder"],
        "historicalPredesignProjectionAdapterFutureSourceAuthority": False,
        "blenderProcessLaunches": 0,
        "blenderRenderApiCalls": 0,
        "renderInvocations": 0,
        "pixelFiles": 0,
    }


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

    schema = json.loads(PRELOCK_SCHEMA_PATH.read_text(encoding="utf-8"))
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
        "schemaSha256": sha256(PRELOCK_SCHEMA_PATH),
        "handoffPath": str(path.relative_to(REPOSITORY_ROOT)),
        "handoffSha256": sha256(path),
        "runnerFileCount": len(expected_hashes),
    }


def source_stage_schema_proof(driver: Any) -> dict[str, Any]:
    import jsonschema

    contract = driver.load_json(CONTRACT_PATH)
    binding = driver.validate_contract(contract)["sourceStage"]
    if not callable(getattr(driver, "build_source_stage_handoff", None)):
        raise RuntimeError("source-stage handoff writer is not bound")
    handoff_output = REPOSITORY_ROOT / binding["handoffOutputPath"]
    if handoff_output.exists():
        raise RuntimeError(f"unauthorized pre-lock source-stage handoff exists: {handoff_output}")
    schema_digest = sha256(SOURCE_STAGE_SCHEMA_V2_PATH)
    if schema_digest != SOURCE_STAGE_SCHEMA_V2_SHA256:
        raise RuntimeError(f"source-stage schema v2 hash mismatch: {schema_digest}")
    schema = json.loads(SOURCE_STAGE_SCHEMA_V2_PATH.read_text(encoding="utf-8"))
    jsonschema.Draft202012Validator.check_schema(schema)
    if schema.get("$id") != "citysim://integration/industrial-l04-source-stage-handoff-v2":
        raise RuntimeError("source-stage schema v2 identity mismatch")
    semantic = semantic_profile_absence_proof(driver, contract)
    return {
        "result": "PASS",
        "state": "BOUND_IMMUTABLE_V2",
        "schemaVersion": 2,
        "schemaPath": str(SOURCE_STAGE_SCHEMA_V2_PATH.relative_to(REPOSITORY_ROOT)),
        "schemaSha256": schema_digest,
        "schemaAuthorityCommit": PUBLISHED_BASELINE,
        "schemaMetaValidation": "PASS",
        "semanticValidator": semantic,
        "rejectedV1Consumed": False,
        "eastIdentityBinding": binding["identity"],
        "futureHandoffPath": binding["handoffOutputPath"],
        "futureHandoffEmission": "blocked_missing_source_production_profile",
        "handoffWriter": "run_production.build_source_stage_handoff",
        "sourceReady": False,
        "productionSelected": False,
    }


def semantic_profile_absence_proof(
    driver: Any,
    contract: dict[str, Any],
) -> dict[str, Any]:
    semantic = load_semantic_validator()
    authority_doc = contract["authorities"]["sourceStageSchemaV2Authority"]
    committed_authority = {
        "path": authority_doc["path"],
        "commit": PUBLISHED_BASELINE,
        "sha256": authority_doc["sha256"],
    }
    authorities = {
        "contract010": contract["authorities"]["contract010"],
        "contract021": contract["authorities"]["contract021"],
        "directionBridge": {
            "documentPath": contract["authorities"]["bridgeV06Acceptance"]["path"],
            "sourceCandidate": "3e01ca6738d7574718f9aeff4b66771eee109feb",
            "integratedProofCommit": "3d76fab8a45807c34198a6d8bb1dd1eeff7be51e",
            "documentSha256": contract["authorities"]["bridgeV06Acceptance"]["sha256"],
            "mappingContractSha256": (
                contract["invariants"]["coordinateBridge"]["v06"]["mappingContractSha256"]
            ),
            "coordinateSystem": "citysim_source_pixels_v1",
        },
        "appearanceLock": {
            "documentPath": authority_doc["path"],
            "commit": PUBLISHED_BASELINE,
            "documentSha256": authority_doc["sha256"],
            "northProcessASourceSha256": "0" * 64,
            "northProcessADecodedRgbaSha256": "0" * 64,
        },
        "lockedMaterialMapping": committed_authority,
        "sourceProductionProfile": {
            "path": (
                "docs/production/evidence/INTEGRATION/"
                "industrial-l04-source-production-profile-v1.json"
            ),
            "commit": PUBLISHED_BASELINE,
            "sha256": "0" * 64,
        },
        "nonAliasInput": {
            **contract["authorities"]["nonAliasInput"],
            "forbiddenDecodedRgbaSha256Count": 44,
            "forbiddenSetSha256": contract["sourceStage"]["nonAliasInput"][
                "forbiddenSetSha256"
            ],
        },
        "nonAliasLoader": contract["authorities"]["nonAliasLoader"],
        "semanticValidator": contract["authorities"]["sourceStageSemanticValidator"],
        "canonicalDecoder": contract["authorities"]["canonicalDecoder"],
    }
    try:
        semantic.verify_authority_artifacts(REPOSITORY_ROOT, authorities)
    except semantic.HandoffError as rejection:
        if rejection.code != "MISSING_REFERENCED_FILE":
            raise RuntimeError(
                f"unexpected semantic-validator rejection: {rejection.code}"
            ) from rejection
        if "sourceProductionProfile.path" not in rejection.detail:
            raise RuntimeError(
                f"semantic validator rejected the wrong artifact: {rejection.detail}"
            ) from rejection
        return {
            "result": "REJECTED_AS_REQUIRED",
            "path": str(SEMANTIC_VALIDATOR_PATH.relative_to(REPOSITORY_ROOT)),
            "sha256": SEMANTIC_VALIDATOR_SHA256,
            "code": rejection.code,
            "detail": rejection.detail,
            "sourceProductionProfile": "absent",
            "blenderProcessLaunches": 0,
            "renderInvocations": 0,
            "pixelFiles": 0,
        }
    raise RuntimeError("semantic validator accepted an absent source-production profile")


def source_stage_guard_proof(driver: Any) -> dict[str, Any]:
    profile = guard_rejection(driver, None, production_entrypoint=True)
    missing = guard_rejection(driver, None, production_entrypoint=False)
    with tempfile.TemporaryDirectory(prefix="play079-east-stale-authority-") as temporary:
        stale_path = pathlib.Path(temporary) / "STALE-APPEARANCE-AUTHORITY.json"
        stale_path.write_text('{"stale":true}\n', encoding="utf-8")
        stale = guard_rejection(driver, stale_path, production_entrypoint=False)
    if profile["code"] != "missing_source_production_profile":
        raise RuntimeError(f"unexpected profile-guard code: {profile['code']}")
    if missing["code"] != "missing_appearance_authority":
        raise RuntimeError(f"unexpected missing-authority code: {missing['code']}")
    if stale["code"] != "stale_appearance_authority":
        raise RuntimeError(f"unexpected stale-authority code: {stale['code']}")
    return {
        "result": "PASS",
        "rejectionStage": "before_renderer_launch",
        "missingSourceProductionProfile": profile,
        "missingAppearanceAuthority": missing,
        "staleAppearanceAuthority": stale,
        "blenderProcessLaunches": 0,
        "blenderRenderApiCalls": 0,
        "imageGenInvocations": 0,
        "normalizerInvocations": 0,
        "contactSheetInvocations": 0,
        "renderInvocations": 0,
        "pixelFiles": 0,
    }


def common_receipt(command: str) -> dict[str, Any]:
    return {
        "schema": "citysim.world-art.source-stage-prelock-command.v1",
        "taskId": "PLAY-079",
        "direction": "east",
        "branch": "codex/citysim-world-art-east",
        "publishedBaseline": PUBLISHED_BASELINE,
        "command": command,
    }


def build_proof(handoff_path: pathlib.Path | None) -> dict[str, Any]:
    driver = load_driver()
    static = static_driver_proof(driver)
    guard = source_stage_guard_proof(driver)
    profile = guard["missingSourceProductionProfile"]
    missing = guard["missingAppearanceAuthority"]
    stale = guard["staleAppearanceAuthority"]
    coordinate_bridge = coordinate_bridge_adoption(driver)
    source_stage_schema = source_stage_schema_proof(driver)
    pixels = pixel_inventory()
    if pixels:
        raise RuntimeError(f"pre-lock pixel files are forbidden: {pixels}")

    result: dict[str, Any] = {
        "schema": "citysim.world-art.prelock-runner-validation.v1",
        "taskId": "PLAY-079",
        "direction": "east",
        "branch": "codex/citysim-world-art-east",
        "baselineCommit": PUBLISHED_BASELINE,
        "result": "PASS",
        "static": static,
        "missingSourceProductionProfile": profile,
        "missingLock": missing,
        "staleAppearanceAuthority": stale,
        "sourceStageGuard": guard,
        "sourceStageSchema": source_stage_schema,
        "coordinateBridge": coordinate_bridge,
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


def run_command(command: str, handoff_path: pathlib.Path | None) -> dict[str, Any]:
    if command == "all":
        return build_proof(handoff_path)
    driver = load_driver()
    receipt = common_receipt(command)
    if command == "describe":
        contract = driver.load_json(CONTRACT_PATH)
        receipt["result"] = "PASS"
        receipt["sourceStage"] = driver.validate_contract(contract)["sourceStage"]
    elif command == "guard":
        receipt["result"] = "PASS"
        receipt["guard"] = source_stage_guard_proof(driver)
    elif command == "schema":
        receipt["result"] = "PASS"
        receipt["schemaValidation"] = source_stage_schema_proof(driver)
    else:
        raise RuntimeError(f"unsupported command: {command}")
    receipt["invocations"] = {
        "blenderProcessLaunches": 0,
        "blenderRenderApiCalls": 0,
        "imageGenInvocations": 0,
        "normalizerInvocations": 0,
        "contactSheetInvocations": 0,
        "renderInvocations": 0,
    }
    receipt["pixelFiles"] = 0
    return receipt


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--command",
        choices=("describe", "guard", "schema", "all"),
        default="all",
    )
    parser.add_argument("--handoff", type=pathlib.Path)
    parser.add_argument("--output", type=pathlib.Path)
    args = parser.parse_args()
    proof = run_command(args.command, args.handoff)
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
