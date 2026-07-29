#!/usr/bin/env python3
"""Validate the PLAY-081 West zero-pixel v2 handoff."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any


SOURCE_ROOT = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-081/"
    "industrial-l04-west-source-v01"
)
EVIDENCE_ROOT = (
    "docs/production/evidence/PLAY-081/industrial-l04-west-source-v01"
)
DEFAULT_HANDOFF = f"{EVIDENCE_ROOT}/WEST-ZERO-PIXEL-V2-HANDOFF.json"
DEFAULT_OUTPUT = (
    f"{EVIDENCE_ROOT}/WEST-ZERO-PIXEL-V2-HANDOFF-VALIDATION.json"
)
PIXEL_SUFFIXES = {".png", ".jpg", ".jpeg", ".tif", ".tiff", ".exr"}
PUBLISHED_BASELINE = "f9cb5fbae1be459ba297a8605347c4174f912ba0"
PRESERVED_CHECKPOINT = "b10386df0b92d5eba0466be0b7a45e4a4dbf9e8c"
SCHEMA_V2_SHA256 = (
    "93efe9ca6d000a2d145098f722338c8e85829d6de6724c3f231a93c06eadf3d7"
)
MISSING_PROFILE_ERROR = (
    "MISSING_REFERENCED_FILE: authorities.sourceProductionProfile.path: "
    "docs/production/evidence/INTEGRATION/"
    "INDUSTRIAL-L04-SOURCE-PRODUCTION-PROFILE.json"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--handoff", default=DEFAULT_HANDOFF)
    parser.add_argument("--output", default=DEFAULT_OUTPUT)
    return parser.parse_args()


def repository_path(root: Path, relative: str) -> Path:
    if not isinstance(relative, str) or not relative or Path(relative).is_absolute():
        raise ValueError(f"invalid repository-relative path: {relative!r}")
    path = (root / relative).resolve()
    path.relative_to(root)
    return path


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text())
    if not isinstance(value, dict):
        raise ValueError(f"{path}: expected object")
    return value


def is_ancestor(root: Path, older: str, newer: str = "HEAD") -> bool:
    if re.fullmatch(r"[0-9a-f]{40}", older) is None:
        return False
    return (
        subprocess.run(
            ["git", "merge-base", "--is-ancestor", older, newer],
            cwd=root,
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ).returncode
        == 0
    )


def main() -> int:
    args = parse_args()
    root = Path(args.repository_root).resolve()
    handoff_path = repository_path(root, args.handoff)
    handoff = load_json(handoff_path)
    failures: list[str] = []

    required_keys = {
        "schemaVersion",
        "stage",
        "identity",
        "lineage",
        "artifacts",
        "blockout",
        "camera",
        "socket",
        "sourceStageV2",
        "validation",
        "invocations",
        "pixelProduction",
        "knownBlockers",
        "sourceReady",
        "integrationAdmitted",
        "rendererQuarantined",
        "productionSelected",
    }
    if set(handoff) != required_keys:
        failures.append("handoff-shape")
    identity = handoff.get("identity", {})
    if identity != {
        "taskId": "PLAY-081",
        "direction": "west",
        "branch": "codex/citysim-world-art-west",
        "logicalID": "industrial_l04_v0_west",
        "orientationTransform": "none",
    }:
        failures.append("identity")
    if handoff.get("schemaVersion") != 1 or handoff.get("stage") != "zero_pixel_prelock":
        failures.append("stage")

    lineage = handoff.get("lineage", {})
    content_commit = lineage.get("contentCommit", "")
    if (
        lineage.get("publishedBaseline") != PUBLISHED_BASELINE
        or lineage.get("preservedRepairCheckpoint") != PRESERVED_CHECKPOINT
        or not is_ancestor(root, PUBLISHED_BASELINE, content_commit)
        or not is_ancestor(root, PRESERVED_CHECKPOINT, content_commit)
        or not is_ancestor(root, content_commit)
    ):
        failures.append("lineage")

    artifact_records = handoff.get("artifacts", {})
    artifacts: dict[str, Path] = {}
    for name, binding in artifact_records.items():
        if not isinstance(binding, dict) or set(binding) != {"path", "sha256"}:
            failures.append(f"artifact-shape:{name}")
            continue
        try:
            path = repository_path(root, binding["path"])
        except (TypeError, ValueError):
            failures.append(f"artifact-path:{name}")
            continue
        if not path.is_file() or sha256(path) != binding["sha256"]:
            failures.append(f"artifact-sha256:{name}")
        artifacts[name] = path

    blockout_proof = (
        load_json(artifacts["blockoutCameraSocketProof"])
        if "blockoutCameraSocketProof" in artifacts
        else {}
    )
    runner_static = (
        load_json(artifacts["runnerStatic"]) if "runnerStatic" in artifacts else {}
    )
    describe = (
        load_json(artifacts["sourceValidatorDescribe"])
        if "sourceValidatorDescribe" in artifacts
        else {}
    )
    schema_gate = (
        load_json(artifacts["sourceStageSchemaGate"])
        if "sourceStageSchemaGate" in artifacts
        else {}
    )
    profile_rejection = (
        load_json(artifacts["missingSourceProductionProfileRejection"])
        if "missingSourceProductionProfileRejection" in artifacts
        else {}
    )
    if (
        blockout_proof.get("passed") is not True
        or runner_static.get("passed") is not True
        or describe.get("passed") is not True
        or schema_gate.get("passed") is not True
        or profile_rejection.get("passed") is not True
    ):
        failures.append("referenced-proof")

    expected_blockout = {
        "sceneGeometryID": "industrial-l04-west-v01-forge-throat-independent",
        "massingProfile": "west-forge-throat-sawtooth-foundry",
        "componentCount": 20,
        "orientationTransform": "none",
        "siblingGeometryConsumed": False,
        "passed": True,
    }
    if any(
        handoff.get("blockout", {}).get(key) != value
        for key, value in expected_blockout.items()
    ):
        failures.append("blockout")
    camera = handoff.get("camera", {})
    if (
        camera.get("projection") != "orthographic-2:1"
        or camera.get("renderViewportPixels") != [1536, 1024]
        or camera.get("literalViewportPixels") != [192, 128]
        or camera.get("maximumRegistrationErrorSourcePixels", 1) >= 0.001
        or camera.get("silhouetteBreaks", 0) < 3
        or camera.get("processOcclusionAreaPixels") != 0
        or camera.get("historicalActualCameraEvidenceRevalidated") is not True
        or camera.get("dccProcessesLaunchedThisRun") != 0
        or camera.get("passed") is not True
    ):
        failures.append("camera")
    socket = handoff.get("socket", {})
    if (
        socket.get("citySimWorldXYZ") != [-28, 0, 0]
        or socket.get("blenderXYZ") != [0, -28, 0]
        or socket.get("sourceXY") != [640, 704]
        or socket.get("maximumErrorSourcePixels", 1) >= 0.001
        or socket.get("passed") is not True
    ):
        failures.append("socket")

    source_stage = handoff.get("sourceStageV2", {})
    if (
        source_stage.get("schemaSha256") != SCHEMA_V2_SHA256
        or source_stage.get("sourceProductionProfileState") != "not_published"
        or source_stage.get("missingProfileSemanticError") != MISSING_PROFILE_ERROR
        or source_stage.get("rejectionStage") != "before_renderer_launch"
        or source_stage.get("passed") is not True
    ):
        failures.append("source-stage-v2")
    if handoff.get("validation") != {
        "blockout": "PASS",
        "camera": "PASS",
        "socket": "PASS",
        "sourceStageV2Structural": "PASS",
        "missingSourceProductionProfile": "PASS",
        "repeatIdentity": "PASS",
    }:
        failures.append("validation")

    expected_zero = {
        "blenderProcessLaunches",
        "blenderRenderApiCalls",
        "dccProcesses",
        "imageGenInvocations",
        "normalizerInvocations",
        "contactSheetInvocations",
        "renderInvocations",
        "pixelFiles",
    }
    invocations = handoff.get("invocations", {})
    if set(invocations) != expected_zero or any(invocations.values()):
        failures.append("invocations")
    if (
        handoff.get("pixelProduction") != "not_run"
        or any(
            handoff.get(key) is not False
            for key in (
                "sourceReady",
                "integrationAdmitted",
                "rendererQuarantined",
                "productionSelected",
            )
        )
    ):
        failures.append("authority-boundary")

    pixel_files: list[str] = []
    generated_caches: list[str] = []
    for relative in (SOURCE_ROOT, EVIDENCE_ROOT):
        directory = repository_path(root, relative)
        for path in directory.rglob("*"):
            if path.is_file() and path.suffix.lower() in PIXEL_SUFFIXES:
                pixel_files.append(str(path.relative_to(root)))
            if "__pycache__" in path.parts:
                generated_caches.append(str(path.relative_to(root)))
    if pixel_files:
        failures.append("pixel-files")
    if generated_caches:
        failures.append("generated-caches")

    result = {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "handoffPath": args.handoff,
        "handoffSha256": sha256(handoff_path),
        "contentCommit": content_commit,
        "publishedBaseline": PUBLISHED_BASELINE,
        "preservedRepairCheckpoint": PRESERVED_CHECKPOINT,
        "sourceStageSchemaSha256": SCHEMA_V2_SHA256,
        "missingProfileSemanticError": source_stage.get(
            "missingProfileSemanticError"
        ),
        "pixelFiles": sorted(pixel_files),
        "generatedCaches": sorted(generated_caches),
        "failures": failures,
        "passed": not failures,
    }
    output_path = repository_path(root, args.output)
    output_path.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
