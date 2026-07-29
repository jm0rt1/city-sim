#!/usr/bin/env python3
"""PLAY-081 source validator with a zero-pixel prelock describe mode.

``describe`` validates the bound source-stage schema v2, Integration's shared
44-master loader/semantic/canonical-decoder authorities, and the task-owned
standard-library PNG decoder without reading a candidate pixel. ``validate``
remains blocked until Integration publishes the appearance lock and exact
source-production profile.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
from typing import Any

import jsonschema

from stdlib_png_rgba import decode_rgba_png, self_test as decoder_self_test
from west_path_safety import (
    PathSafetyError,
    expected_process_paths,
    lexical_repository_path,
    validate_process_layout,
)


DEFAULT_CONTRACT = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-081/"
    "industrial-l04-west-source-v01/RUNNER-CONTRACT.json"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", default=DEFAULT_CONTRACT)
    parser.add_argument("--mode", required=True, choices=("describe", "validate"))
    parser.add_argument("--output")
    return parser.parse_args()


def repository_path(root: Path, relative: str) -> Path:
    if not relative or Path(relative).is_absolute():
        raise ValueError(f"path must be repository-relative: {relative!r}")
    path = (root / relative).resolve()
    path.relative_to(root)
    return path


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path}: expected JSON object")
    return value


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def validate_artifact(
    root: Path,
    binding: dict[str, Any],
    name: str,
) -> Path:
    path = repository_path(root, binding["path"])
    if not path.is_file():
        raise ValueError(f"{name}: missing {binding['path']}")
    actual = sha256(path)
    if actual != binding["sha256"]:
        raise ValueError(
            f"{name}: SHA-256 mismatch expected={binding['sha256']} actual={actual}"
        )
    return path


def validate_non_alias_input(
    root: Path,
    loader_binding: dict[str, Any],
    binding: dict[str, Any],
) -> tuple[set[str], dict[str, Any]]:
    loader_path = validate_artifact(root, loader_binding, "non-alias-loader")
    input_path = validate_artifact(root, binding, "non-alias-input")
    spec = importlib.util.spec_from_file_location(
        "citysim_accepted_master_non_alias_v1",
        loader_path,
    )
    if spec is None or spec.loader is None:
        raise ValueError("non-alias-loader: unable to load shared authority")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    forbidden = module.load_forbidden_decoded_rgba(root, input_path)
    if (
        len(forbidden) != binding["forbiddenDecodedRgbaSha256Count"]
        or module.FORBIDDEN_SET_SHA256 != binding["forbiddenSetSha256"]
    ):
        raise ValueError("non-alias-loader: result binding")
    return set(forbidden), {
        "path": binding["path"],
        "sha256": binding["sha256"],
        "loader": {
            "path": loader_binding["path"],
            "sha256": loader_binding["sha256"],
        },
        "schema": module.SCHEMA,
        "forbiddenDecodedRgbaSha256Count": len(forbidden),
        "forbiddenSetSha256": module.FORBIDDEN_SET_SHA256,
        "candidatePixelFilesRead": 0,
        "passed": True,
    }


def validate_source_stage_schema(
    root: Path,
    binding: dict[str, Any],
) -> dict[str, Any]:
    if binding.get("state") != "bound_integration_v2":
        raise ValueError("source-stage-schema: v2 is not bound")
    schema_path = validate_artifact(root, binding, "source-stage-schema")
    schema = load_json(schema_path)
    jsonschema.Draft202012Validator.check_schema(schema)
    west = schema["$defs"]["westIdentity"]["allOf"][1]["properties"]
    west_registration = schema["$defs"]["westRegistration"]["allOf"][1][
        "properties"
    ]
    authorities = schema["$defs"]["authorities"]["properties"]
    authorized = schema["allOf"][2]["else"]["properties"]["launch"][
        "properties"
    ]["authorizedProcesses"]["const"]
    if (
        schema.get("$id") != binding.get("schemaId")
        or west["direction"].get("const") != "west"
        or west["branch"].get("const")
        != "codex/citysim-world-art-west"
        or west["logicalID"].get("const")
        != "industrial_l04_v0_west"
        or authorized != ["A", "B", "C"]
        or west_registration["frontageSocketSource"].get("const")
        != [640, 704]
        or authorities["nonAliasLoader"]["properties"]["sha256"].get("const")
        != "2c44bc3a4ffe3fdfc68a477b70f3af9478122e9b796543f32a154859ac300a39"
        or authorities["semanticValidator"]["properties"]["sha256"].get("const")
        != "7a0613af9998a222a583a70930ce3afc5ec1902793f03201f899a2bb4129f340"
        or authorities["canonicalDecoder"]["properties"]["sha256"].get("const")
        != "2be2b57d0c9bb73e8a4438c69aa4230eba08c4b87937fae4d4e048244b9beaab"
    ):
        raise ValueError("source-stage-schema: West contract")
    return {
        "state": binding["state"],
        "path": binding["path"],
        "sha256": binding["sha256"],
        "schemaId": schema["$id"],
        "draft202012MetaSchema": "pass",
        "westIdentity": {
            "taskId": "PLAY-081",
            "direction": "west",
            "branch": "codex/citysim-world-art-west",
            "logicalID": "industrial_l04_v0_west",
            "frontageSocketSource": [640, 704],
        },
        "futureAuthorizedProcesses": authorized,
        "candidatePacketValidation":
            "not_run_pending_source_production_profile",
        "placeholderHashesUsed": False,
        "passed": True,
    }


def alpha_report(size: tuple[int, int], rgba: bytes) -> dict[str, Any]:
    width, height = size
    occupied: list[tuple[int, int]] = []
    hidden_rgb = 0
    visible_chroma = 0
    edge_contact = 0
    for index in range(width * height):
        red, green, blue, alpha = rgba[index * 4 : index * 4 + 4]
        x = index % width
        y = index // width
        if alpha:
            occupied.append((x, y))
            if red >= 230 and blue >= 230 and green <= 25:
                visible_chroma += 1
            if x in (0, width - 1) or y in (0, height - 1):
                edge_contact += 1
        elif red or green or blue:
            hidden_rgb += 1
    bounds = None
    if occupied:
        xs = [point[0] for point in occupied]
        ys = [point[1] for point in occupied]
        bounds = [min(xs), min(ys), max(xs), max(ys)]
    return {
        "occupiedBounds": bounds,
        "occupiedPixels": len(occupied),
        "hiddenRgbPixels": hidden_rgb,
        "visibleChromaSpillPixels": visible_chroma,
        "edgeContactPixels": edge_contact,
        "passed": (
            bool(occupied)
            and hidden_rgb == 0
            and visible_chroma == 0
            and edge_contact == 0
        ),
    }


def describe(root: Path, contract: dict[str, Any]) -> dict[str, Any]:
    source_stage = contract["sourceStage"]
    decoder_path = validate_artifact(root, source_stage["pngDecoder"], "png-decoder")
    decoder_report = decoder_self_test()
    decoder_report.update(
        {
            "path": source_stage["pngDecoder"]["path"],
            "sha256": sha256(decoder_path),
            "pillowImported": False,
        }
    )
    forbidden, non_alias = validate_non_alias_input(
        root,
        source_stage["nonAliasLoader"],
        source_stage["nonAliasInput"],
    )
    schema = validate_source_stage_schema(
        root,
        source_stage["handoffSchema"],
    )
    passed = (
        decoder_report["passed"] is True
        and len(forbidden) == 44
        and non_alias["passed"] is True
        and schema["state"] == "bound_integration_v2"
        and contract["sourceReady"] is False
        and contract["productionSelected"] is False
    )
    return {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "mode": "describe",
        "sourceStageSchema": schema,
        "nonAliasInput": non_alias,
        "sharedSemanticValidator": {
            **source_stage["semanticValidator"],
            "passed": (
                sha256(
                    validate_artifact(
                        root,
                        source_stage["semanticValidator"],
                        "semantic-validator",
                    )
                )
                == source_stage["semanticValidator"]["sha256"]
            ),
        },
        "canonicalDecoder": {
            **source_stage["canonicalDecoder"],
            "passed": (
                sha256(
                    validate_artifact(
                        root,
                        source_stage["canonicalDecoder"],
                        "canonical-decoder",
                    )
                )
                == source_stage["canonicalDecoder"]["sha256"]
            ),
        },
        "pngDecoder": decoder_report,
        "futureChecks": [
            "fresh-process provenance",
            "decoded raw and semantic RGBA A/B/C identity",
            "alpha, chroma, hidden-RGB, bounds, and registration",
            "literal-192 survival",
            "candidate decoded-RGBA rejection against canonical 44-master set",
        ],
        "pixelFilesRead": 0,
        "blenderProcessLaunches": 0,
        "blenderRenderApiCalls": 0,
        "imageGenInvocations": 0,
        "normalizerInvocations": 0,
        "contactSheetInvocations": 0,
        "renderInvocations": 0,
        "rgba": "not_run",
        "literal192": "not_run",
        "abcIdentity": "not_run",
        "normalization": "not_run",
        "sourceReady": False,
        "productionSelected": False,
        "passed": passed,
    }


def validate_pixels(
    root: Path,
    contract: dict[str, Any],
    forbidden_hashes: set[str],
) -> dict[str, Any]:
    if contract.get("state") != "ready_for_source_render":
        raise ValueError("pixel validation blocked pending post-lock production authority")
    layout = validate_process_layout(root, contract, require_absent=False)
    if not layout["passed"]:
        raise ValueError(
            "unsafe A/B/C output layout before pixel read: "
            + ",".join(layout["errors"])
        )
    failures: list[str] = []
    processes: dict[str, Any] = {}
    raw_hashes: dict[str, str] = {}
    semantic_hashes: dict[str, str] = {}
    occupied_bounds: dict[str, Any] = {}
    provenance_ids: list[str] = []

    for process_id in ("A", "B", "C"):
        inventory = contract["outputInventory"]["processes"][process_id]
        expected = expected_process_paths(process_id)
        try:
            required = {
                name: lexical_repository_path(
                    root,
                    inventory[name],
                    expected=expected[name],
                )
                for name in (
                    "raw",
                    "semantic",
                    "provenance",
                    "objectMapping",
                    "registration",
                )
            }
        except PathSafetyError as error:
            raise ValueError(
                f"unsafe process-{process_id} output before pixel read: {error}"
            ) from error
        missing = sorted(name for name, path in required.items() if not path.is_file())
        if missing:
            failures.append(f"process-{process_id}:missing:{','.join(missing)}")
            continue
        raw_size, raw_bytes = decode_rgba_png(required["raw"])
        semantic_size, semantic_bytes = decode_rgba_png(required["semantic"])
        raw_hashes[process_id] = sha256_bytes(raw_bytes)
        semantic_hashes[process_id] = sha256_bytes(semantic_bytes)
        alpha = alpha_report(raw_size, raw_bytes)
        occupied_bounds[process_id] = alpha["occupiedBounds"]
        if not alpha["passed"]:
            failures.append(f"process-{process_id}:alpha-chroma-hidden-rgb")
        if raw_size != tuple(contract["invariants"]["camera"]["renderViewportPixels"]):
            failures.append(f"process-{process_id}:raw-size")
        if semantic_size != raw_size:
            failures.append(f"process-{process_id}:semantic-size")

        provenance = load_json(required["provenance"])
        registration = load_json(required["registration"])
        provenance_ids.append(provenance.get("processId"))
        if provenance.get("processId") != process_id:
            failures.append(f"process-{process_id}:provenance-id")
        if provenance.get("appearanceLock") != contract["appearanceLock"]:
            failures.append(f"process-{process_id}:appearance-lock-provenance")
        if provenance.get("coordinateBridge") != contract["coordinateBridge"]["v06"]:
            failures.append(f"process-{process_id}:coordinate-bridge-provenance")
        expected_registration = contract["invariants"]["registration"]
        if registration.get("footprintWorldXZ") != expected_registration[
            "contactPolygonWorldXZ"
        ]:
            failures.append(f"process-{process_id}:footprint")
        if registration.get("pivotWorldXYZ") != expected_registration[
            "groundPivotWorldXYZ"
        ]:
            failures.append(f"process-{process_id}:pivot")
        if registration.get("socketWorldXYZ") != expected_registration[
            "frontageSocketWorldXYZ"
        ]:
            failures.append(f"process-{process_id}:socket")
        processes[process_id] = {
            "rawDecodedRgbaSha256": raw_hashes[process_id],
            "semanticDecodedRgbaSha256": semantic_hashes[process_id],
            "alpha": alpha,
            "rawSize": list(raw_size),
            "semanticSize": list(semantic_size),
        }

    abc_raw_equal = len(set(raw_hashes.values())) == 1 and len(raw_hashes) == 3
    abc_semantic_equal = (
        len(set(semantic_hashes.values())) == 1 and len(semantic_hashes) == 3
    )
    bounds_equal = (
        len({json.dumps(value) for value in occupied_bounds.values()}) == 1
        and len(occupied_bounds) == 3
    )
    provenance_unique = sorted(provenance_ids) == ["A", "B", "C"]
    if not abc_raw_equal:
        failures.append("abc:raw-decoded-rgba")
    if not abc_semantic_equal:
        failures.append("abc:semantic-decoded-rgba")
    if not bounds_equal:
        failures.append("abc:occupied-bounds")
    if not provenance_unique:
        failures.append("abc:fresh-process-provenance")
    accepted_hash = next(iter(raw_hashes.values()), "")
    non_alias = bool(accepted_hash) and accepted_hash not in forbidden_hashes
    if not non_alias:
        failures.append("catalog:decoded-rgba-alias")

    literal_path = repository_path(
        root,
        contract["outputInventory"]["review"]["literal192Color"],
    )
    literal_size = None
    if literal_path.is_file():
        literal_size, _ = decode_rgba_png(literal_path)
    literal_pass = literal_size == (192, 128)
    if not literal_pass:
        failures.append("literal192:not-192x128")

    return {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "processes": processes,
        "abcIdentity": {
            "rawDecodedRgbaEqual": abc_raw_equal,
            "semanticDecodedRgbaEqual": abc_semantic_equal,
            "occupiedBoundsEqual": bounds_equal,
            "freshProcessProvenance": provenance_unique,
        },
        "literal192": {
            "path": contract["outputInventory"]["review"]["literal192Color"],
            "size": list(literal_size) if literal_size else None,
            "passed": literal_pass,
        },
        "nonAliasing": {
            "candidateDecodedRgbaSha256": accepted_hash or None,
            "forbiddenHashCount": len(forbidden_hashes),
            "passed": non_alias,
        },
        "failures": sorted(set(failures)),
        "passed": not failures,
        "productionSelected": False,
    }


def main() -> int:
    args = parse_args()
    root = Path(args.repository_root).resolve()
    contract = load_json(repository_path(root, args.contract))
    if args.mode == "describe":
        result = describe(root, contract)
    else:
        if not args.output:
            raise SystemExit("--mode validate requires --output")
        forbidden, _ = validate_non_alias_input(
            root,
            contract["sourceStage"]["nonAliasLoader"],
            contract["sourceStage"]["nonAliasInput"],
        )
        result = validate_pixels(root, contract, forbidden)
        output = repository_path(root, args.output)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
