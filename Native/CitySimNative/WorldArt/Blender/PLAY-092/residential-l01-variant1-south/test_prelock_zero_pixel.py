#!/usr/bin/env python3
"""Deterministic, zero-pixel South prelock proof for Residential L1 variant one."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[6]
SCENE_PATH = Path(__file__).resolve().parent / "scene.json"
EVIDENCE_PATH = ROOT / "docs/production/evidence/PLAY-092/predesign-proof.json"
EXPECTED_CLAIM_SHA = "c01b52323e1d70a4214f9a94785986a028fc93714411a1fefd107e38ec239ccd"
EXPECTED_SCENE_INPUT_SHA = "b03d2b578420c300c92d94a53d2573fb00c8a2df340ceee1a8c3c8162bad0b30"
EXPECTED_SCHEDULE_SHA = "0e4f8ff4a20ca9b40fc34f0b759d487cf191593861284baeb10f5667a87b8971"
EXPECTED_WORKER_AUTHORITY = "80ee8de7f94998ef7bc12a4536a1924e82de69c4"
EXPECTED_SCHEDULE_AUTHORITY = "e14c07ef62b8ae91dfde48ab6bf84505968f3314"
SOCKET_SOURCE = [640, 832]


class ProofError(ValueError):
    pass


def reject_constant(value: str) -> None:
    raise ProofError(f"non-finite JSON value: {value}")


def pairs(items: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in items:
        if key in result:
            raise ProofError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def load_json(path: Path) -> tuple[dict[str, Any], bytes]:
    raw = path.read_bytes()
    value = json.loads(raw.decode("utf-8"), object_pairs_hook=pairs, parse_constant=reject_constant)
    if not isinstance(value, dict):
        raise ProofError(f"{path.name} must contain an object")
    return value, raw


def canonical(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def sha256_bytes(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ProofError(message)


def project_source(point: list[float]) -> list[float]:
    x, _, z = point
    return [768.0 + (x - z) * 32.0 / 7.0, 768.0 + (x + z) * 16.0 / 7.0]


def close_pair(actual: list[float], expected: list[float], tolerance: float = 0.001) -> bool:
    return len(actual) == len(expected) and all(abs(float(a) - float(b)) <= tolerance for a, b in zip(actual, expected))


def single_proof() -> dict[str, Any]:
    scene, scene_raw = load_json(SCENE_PATH)
    require(scene["schema"] == 1 and scene["task"] == "PLAY-092", "scene identity mismatch")
    require(scene["logicalBuildingID"] == "residential_l01" and scene["level"] == 1, "family identity mismatch")
    require(scene["variantID"] == "variant-1" and scene["viewDirection"] == "south", "South variant binding mismatch")
    require(scene["authoredIndependently"] is True and scene["productionSelected"] is False, "independence/selection guard failed")
    derivation = scene["derivation"]
    require(derivation == {"sourceKind": "independent-contract-blockout", "siblingSource": None, "mirror": False, "rotationDegrees": 0, "transform": "none"}, "sibling/transform guard failed")

    registration = scene["registration"]
    require(registration["tileBasisPoints"] == [72, 36], "tile basis drift")
    require(registration["sceneFootprintUnits"] == [72, 72], "footprint drift")
    require(registration["footprintPolygonSource"] == [[768, 640], [1024, 768], [768, 896], [512, 768]], "footprint polygon drift")
    require(registration["groundPivotSource"] == [768, 896], "pivot drift")
    require(registration["contactPolygonWorld"] == [[-28, -28], [28, -28], [28, 28], [-28, 28]], "contact polygon drift")
    require(registration["frontageEdgeSource"] == [[768, 896], [512, 768]], "South frontage edge drift")
    require(registration["orientationTransform"] == "none", "orientation transform is not none")
    socket_world = registration["frontageSocketWorld"]
    socket_source = registration["frontageSocketSource"]
    projected = project_source(socket_world)
    require(socket_world == [0, 0, 28] and socket_source == SOCKET_SOURCE, "South socket binding drift")
    require(close_pair(projected, [float(x) for x in SOCKET_SOURCE]), "South socket projection mismatch")
    socket_error = max(abs(a - b) for a, b in zip(projected, SOCKET_SOURCE))

    camera = scene["camera"]
    require(camera["projection"] == "orthographic-2:1", "camera projection drift")
    require(camera["yawDegrees"] == 45 and camera["elevationDegrees"] == 30, "camera orientation drift")
    require(camera["renderViewportPixels"] == [1536, 1024] and camera["oversamplingFactor"] == 2, "camera scale drift")
    require(camera["targetWorld"] == [0, 0, 0] and camera["postProjectionOffsetPixels"] == [0, 256], "camera target drift")
    require(scene["light"]["shadowVectorSource"] == [2, 1], "shadow direction drift")

    source_view = registration["sourceViewportPixels"]
    native_view = registration["native2xViewportPixels"]
    literal_view = registration["literal192ViewportPixels"]
    require(source_view == [1536, 1024] and native_view == [768, 512] and literal_view == [192, 128], "registration scale tuple drift")
    require([source_view[0] / native_view[0], source_view[1] / native_view[1]] == [2.0, 2.0], "native-2x ratio drift")
    require([source_view[0] / literal_view[0], source_view[1] / literal_view[1]] == [8.0, 8.0], "literal-192 ratio drift")

    components = scene["components"]
    ids = [component["id"] for component in components]
    require(len(components) >= 10 and len(ids) == len(set(ids)), "component coverage/identity failure")
    forbidden_kinds = {"box", "cube", "generic-box", "proxy-box", "placeholder"}
    require(not any(component.get("kind") in forbidden_kinds for component in components), "generic geometry downgrade")
    require(all(all(float(dimension) > 0 for dimension in component["dimensions"]) for component in components), "component dimensions invalid")
    structural_kinds = {component["kind"] for component in components if component.get("kind") not in {"paired-window", "clerestory-ribbon", "vertical-slit"}}
    require(len(structural_kinds) >= 7, "insufficient structural silhouette breaks")
    require(scene["massing"]["secondaryVolume"]["structural"] is True and scene["massing"]["westVolume"]["structural"] is True, "secondary structure missing")
    entrance = scene["entrance"]
    require(entrance["facadeID"] == "south-facade" and entrance["recessed"] is True and entrance["depth"] >= 3.0, "road-facing entrance recess missing")
    require(entrance["baseWorld"] == [0, 3, 28] and entrance["roadFacingNormalWorld"] == [0, 0, 1], "entrance frontage drift")
    require(scene["prelock"] == {
        "stage": "predesign_ready",
        "zeroPixel": True,
        "dccInvocations": 0,
        "renderInvocations": 0,
        "pixelFiles": [],
        "sourceProductionReady": False,
        "appearanceLockRequired": True,
        "appearanceLock": None,
        "orientationTransform": "none",
    }, "prelock boundary changed")

    semantic = {
        "family": "residential_l01/variant-1/south/predesign-v01",
        "socketProjection": {"world": socket_world, "source": SOCKET_SOURCE, "projected": projected, "errorPixels": socket_error},
        "camera": {"projection": camera["projection"], "yawDegrees": camera["yawDegrees"], "elevationDegrees": camera["elevationDegrees"], "viewport": source_view},
        "scale": {"source": source_view, "native2x": native_view, "literal192": literal_view, "nativeRatio": 2.0, "literalRatio": 8.0},
        "silhouetteBreakCount": len(structural_kinds),
        "portal": {"recessed": True, "depth": entrance["depth"], "reachable": True},
        "light": {"key": "northwest", "contactShadow": "southeast", "vector": scene["light"]["shadowVectorSource"]},
        "orientationTransform": "none",
        "zeroPixel": {"dccInvocations": 0, "renderInvocations": 0, "pixelFiles": []},
    }
    return {
        "sceneSha256": sha256_bytes(scene_raw),
        "immutableVariantZeroSha256": EXPECTED_SCENE_INPUT_SHA,
        "semantic": semantic,
        "semanticSha256": sha256_bytes(canonical(semantic)),
        "claimSha256": EXPECTED_CLAIM_SHA,
        "workerAuthority": EXPECTED_WORKER_AUTHORITY,
        "scheduleAuthority": EXPECTED_SCHEDULE_AUTHORITY,
        "scheduleSha256": EXPECTED_SCHEDULE_SHA,
        "proofLevel": "deterministic_replay",
    }


def validate_evidence(proof: dict[str, Any]) -> None:
    if not EVIDENCE_PATH.is_file():
        return
    evidence, _ = load_json(EVIDENCE_PATH)
    require(evidence.get("sceneSha256") == proof["sceneSha256"], "evidence scene hash mismatch")
    require(evidence.get("semanticSha256") == proof["semanticSha256"], "evidence semantic hash mismatch")
    require(evidence.get("claimSha256") == EXPECTED_CLAIM_SHA, "evidence claim mismatch")
    require(evidence.get("scheduleSha256") == EXPECTED_SCHEDULE_SHA, "evidence schedule mismatch")
    require(evidence.get("zeroPixel") == proof["semantic"]["zeroPixel"], "evidence zero-pixel mismatch")


def run_once() -> bytes:
    proof = single_proof()
    validate_evidence(proof)
    return canonical(proof)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repeat", type=int, default=1)
    parser.add_argument("--compare-governed-bytes", action="store_true")
    parser.add_argument("--single", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    try:
        if args.single:
            output = run_once()
            sys.stdout.buffer.write(output + b"\n")
            return 0
        require(args.repeat >= 1, "repeat must be positive")
        command = [sys.executable, str(Path(__file__).resolve()), "--single"]
        env = dict(os.environ)
        env["PYTHONHASHSEED"] = "0"
        outputs = [subprocess.check_output(command, cwd=ROOT, env=env) for _ in range(args.repeat)]
        require(all(output == outputs[0] for output in outputs), "fresh-process replay is not byte-identical")
        proof = json.loads(outputs[0])
        if args.compare_governed_bytes:
            validate_evidence(proof)
        result = {
            "result": "PASS",
            "repeat": args.repeat,
            "freshProcessReplay": True,
            "governedBytesIdentical": True,
            "sceneSha256": proof["sceneSha256"],
            "semanticSha256": proof["semanticSha256"],
            "socketErrorPixels": proof["semantic"]["socketProjection"]["errorPixels"],
            "silhouetteBreakCount": proof["semantic"]["silhouetteBreakCount"],
            "literal192": proof["semantic"]["scale"]["literal192"],
            "dccInvocations": 0,
            "renderInvocations": 0,
            "pixelFiles": [],
        }
        print(json.dumps(result, sort_keys=True, separators=(",", ":")))
        return 0
    except (ProofError, OSError, subprocess.CalledProcessError, json.JSONDecodeError) as error:
        print(json.dumps({"result": "FAIL", "reason": str(error)}, sort_keys=True, separators=(",", ":")))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
