#!/usr/bin/env python3
"""PLAY-081 source validator with a zero-pixel prelock describe mode.

``describe`` validates the future source-stage schema, canonical 44-master
non-alias input, and task-owned standard-library PNG decoder without reading a
candidate pixel. ``validate`` remains blocked until Integration publishes the
appearance lock and post-lock production authority.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path
from typing import Any

import jsonschema

from stdlib_png_rgba import decode_rgba_png, self_test as decoder_self_test


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


def _accepted_commit_is_ancestor(root: Path, commit: str) -> bool:
    object_check = subprocess.run(
        ["git", "cat-file", "-e", f"{commit}^{{commit}}"],
        cwd=root,
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if object_check.returncode:
        return False
    ancestry = subprocess.run(
        ["git", "merge-base", "--is-ancestor", commit, "HEAD"],
        cwd=root,
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return ancestry.returncode == 0


def validate_non_alias_input(
    root: Path,
    binding: dict[str, Any],
) -> tuple[set[str], dict[str, Any]]:
    input_path = validate_artifact(root, binding, "non-alias-input")
    source = load_json(input_path)
    if source.get("schema") != "citysim.integration.accepted-building-non-alias-input.v1":
        raise ValueError("non-alias-input: schema")
    if source.get("disposition") != "derived-validation-input":
        raise ValueError("non-alias-input: disposition")
    if source.get("authoritative") is not False:
        raise ValueError("non-alias-input: authority boundary")

    authority_inputs = source["authorityInputs"]
    artifact_checks: dict[str, str] = {}
    for name in ("shippingManifest", "generator", "derivedInventory"):
        path = validate_artifact(root, authority_inputs[name], f"non-alias-{name}")
        artifact_checks[name] = sha256(path)

    source_only = authority_inputs["acceptedSourceOnlyFamilies"]
    if len(source_only) != 1 or source_only[0].get("family") != "industrial_l03":
        raise ValueError("non-alias-input: accepted source-only family")
    accepted = source_only[0]
    for label, path_key, hash_key in (
        ("industrial-l03-manifest", "manifestPath", "manifestSha256"),
        ("industrial-l03-acceptance", "acceptancePath", "acceptanceSha256"),
    ):
        path = validate_artifact(
            root,
            {"path": accepted[path_key], "sha256": accepted[hash_key]},
            label,
        )
        artifact_checks[label] = sha256(path)
    if not _accepted_commit_is_ancestor(root, accepted["acceptedCommit"]):
        raise ValueError("non-alias-input: accepted Industrial L3 commit ancestry")

    inventory_path = repository_path(root, authority_inputs["derivedInventory"]["path"])
    inventory = load_json(inventory_path)
    masters = inventory.get("masters")
    if (
        not isinstance(masters, list)
        or inventory.get("acceptedMasterCount") != 44
        or len(masters) != 44
    ):
        raise ValueError("non-alias-input: derived inventory count")
    logical_ids = [record.get("logicalID") for record in masters]
    file_hashes = [record.get("sha256Before") for record in masters]
    decoded_hashes = [record.get("decodedRGBASHA256") for record in masters]
    lowercase_hex = all(
        isinstance(value, str)
        and len(value) == 64
        and value == value.lower()
        and all(character in "0123456789abcdef" for character in value)
        for value in decoded_hashes
    )
    if (
        logical_ids != sorted(logical_ids)
        or len(set(logical_ids)) != 44
        or len(set(file_hashes)) != 44
        or len(set(decoded_hashes)) != 44
        or not lowercase_hex
    ):
        raise ValueError("non-alias-input: inventory order or uniqueness")
    forbidden_bytes = "".join(
        f"{value}\n" for value in sorted(decoded_hashes)
    ).encode("ascii")
    forbidden_set_sha256 = sha256_bytes(forbidden_bytes)
    counts = source.get("counts", {})
    if (
        counts.get("shippingDirectionalMasters") != 40
        or counts.get("acceptedSourceOnlyMasters") != 4
        or counts.get("total") != 44
        or source.get("forbiddenDecodedRgbaSha256Count") != 44
        or forbidden_set_sha256 != source.get("forbiddenSetSha256")
    ):
        raise ValueError("non-alias-input: canonical forbidden set")
    return set(decoded_hashes), {
        "path": binding["path"],
        "sha256": binding["sha256"],
        "schema": source["schema"],
        "disposition": source["disposition"],
        "shippingDirectionalMasters": 40,
        "acceptedSourceOnlyMasters": 4,
        "acceptedSourceOnlyFamily": "industrial_l03",
        "forbiddenDecodedRgbaSha256Count": 44,
        "forbiddenSetSha256": forbidden_set_sha256,
        "logicalIdOrder": "ascii-ascending",
        "candidatePixelFilesRead": 0,
        "authorityArtifacts": artifact_checks,
        "passed": True,
    }


def validate_source_stage_schema(
    root: Path,
    binding: dict[str, Any],
) -> dict[str, Any]:
    if binding.get("state") == "pending_integration_v2":
        if binding.get("path") is not None or binding.get("sha256") is not None:
            raise ValueError("source-stage-schema: pending v2 binding must be null")
        return {
            "state": "pending_integration_v2",
            "path": None,
            "sha256": None,
            "candidatePacketValidation": "not_run",
            "placeholderHashesUsed": False,
            "passed": None,
        }
    schema_path = validate_artifact(root, binding, "source-stage-schema")
    schema = load_json(schema_path)
    jsonschema.Draft202012Validator.check_schema(schema)
    identity_options = schema["$defs"]["identity"]["oneOf"]
    west = next(
        option
        for option in identity_options
        if option["properties"]["taskId"].get("const") == "PLAY-081"
    )
    authorized = schema["allOf"][2]["else"]["properties"]["launch"]["properties"][
        "authorizedProcesses"
    ]["const"]
    if (
        schema.get("$id") != binding.get("schemaId")
        or west["properties"]["direction"].get("const") != "west"
        or west["properties"]["branch"].get("const")
        != "codex/citysim-world-art-west"
        or west["properties"]["logicalID"].get("const")
        != "industrial_l04_v0_west"
        or authorized != ["A", "B", "C"]
    ):
        raise ValueError("source-stage-schema: West contract")
    return {
        "path": binding["path"],
        "sha256": binding["sha256"],
        "schemaId": schema["$id"],
        "draft202012MetaSchema": "pass",
        "westIdentity": {
            "taskId": "PLAY-081",
            "direction": "west",
            "branch": "codex/citysim-world-art-west",
            "logicalID": "industrial_l04_v0_west",
        },
        "futureAuthorizedProcesses": authorized,
        "candidatePacketValidation": "not_run_pending_appearance_lock_and_post_lock_authority",
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
        and schema["state"] == "pending_integration_v2"
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
    failures: list[str] = []
    processes: dict[str, Any] = {}
    raw_hashes: dict[str, str] = {}
    semantic_hashes: dict[str, str] = {}
    occupied_bounds: dict[str, Any] = {}
    provenance_ids: list[str] = []

    for process_id in ("A", "B", "C"):
        inventory = contract["outputInventory"]["processes"][process_id]
        required = {
            name: repository_path(root, inventory[name])
            for name in (
                "raw",
                "semantic",
                "provenance",
                "objectMapping",
                "registration",
            )
        }
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
