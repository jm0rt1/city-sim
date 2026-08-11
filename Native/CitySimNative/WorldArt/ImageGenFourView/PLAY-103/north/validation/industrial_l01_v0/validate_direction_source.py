#!/usr/bin/env python3
"""Focused deterministic validator for the PLAY-103 industrial North source."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REPO = next(parent for parent in ROOT.parents if (parent / ".git").exists())
PROCESSOR = ROOT / "process_direction_source.py"
EVIDENCE = REPO / "docs/production/evidence/PLAY-103/industrial-l01-v0/validation.json"
RAW = ROOT / "raw/industrial_l01_v0/north-v01.png"
EXPECTED_RAW = "81b1770d6e85f5f92a6a619ac55ddff29bab36358c074a6bbd57a6e434a151a7"
ROUTE_ID = "north-v3:play-103-currentd3be-industrial-l01-v0-recent-image-v1"
ROUTE_FILE_SHA = "4225e9191762673af82bf42e673634b1b5df83f191a821a02c1b02553a67482b"
ROUTE_CANONICAL_SHA = "daceb1161d9153a6ec0bb85dd8542e11ee6816a6e775a3c0a60078a4f624ff6a"
TRANSPORT = "central_view_image_recent_image_bridge"
TRACKED = (
    "prompts/industrial_l01_v0-north.json",
    "provenance/industrial_l01_v0-north.json",
    "normalized/industrial_l01_v0/block/north-v01.png",
    "normalized/industrial_l01_v0/neighborhood/north-v01.png",
    "normalized/industrial_l01_v0/city/north-v01.png",
    "output/contact-sheets/north-industrial_l01_v0-source.png",
    "output/contact-sheets/north-industrial_l01_v0-game-scale.png",
    "output/contact-sheets/north-industrial_l01_v0-grayscale.png",
    "process/industrial_l01_v0-north-manifest.json",
    "handoff/industrial_l01_v0-north-handoff.json",
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def file_map(root: Path) -> dict[str, str]:
    return {relative: sha256(root / relative) for relative in TRACKED}


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def fresh_run(destination: Path) -> dict[str, str]:
    environment = dict(os.environ)
    environment["PYTHONHASHSEED"] = "0"
    runtime = Path("/Users/James/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3")
    completed = subprocess.run([str(runtime), str(PROCESSOR), "--output-root", str(destination)], cwd=REPO, env=environment, text=True, capture_output=True)
    if completed.returncode:
        raise RuntimeError(completed.stderr.strip() or completed.stdout.strip())
    return file_map(destination)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repeat", type=int, default=2)
    args = parser.parse_args()
    if args.repeat < 2:
        raise ValueError("deterministic replay requires at least two fresh processes")
    if not RAW.is_file() or sha256(RAW) != EXPECTED_RAW:
        raise ValueError("North raw hash mismatch")
    committed = file_map(ROOT)
    if len(committed) != len(TRACKED):
        raise ValueError("North source packet is incomplete")
    replay_maps = []
    with tempfile.TemporaryDirectory(prefix="play-103-industrial-l01-v0-replay-") as temporary:
        for index in range(args.repeat):
            replay_maps.append(fresh_run(Path(temporary) / f"run-{index + 1}"))
    if any(mapping != replay_maps[0] for mapping in replay_maps[1:]):
        raise ValueError("fresh deterministic replays differ")
    if replay_maps[0] != committed:
        changed = sorted(path for path in TRACKED if replay_maps[0].get(path) != committed.get(path))
        raise ValueError(f"committed packet differs from fresh replay: {changed}")
    manifest = json.loads((ROOT / "process/industrial_l01_v0-north-manifest.json").read_text())
    handoff = json.loads((ROOT / "handoff/industrial_l01_v0-north-handoff.json").read_text())
    provenance = json.loads((ROOT / "provenance/industrial_l01_v0-north.json").read_text())
    if manifest.get("route", {}).get("routeId") != ROUTE_ID or manifest["route"]["routeFileSha256"] != ROUTE_FILE_SHA or manifest["route"]["routeCanonicalSha256"] != ROUTE_CANONICAL_SHA:
        raise ValueError("route binding missing")
    if provenance.get("transport") != TRANSPORT or provenance.get("tool", {}).get("calls") != 1:
        raise ValueError("central ImageGen transport provenance mismatch")
    for packet in (manifest, handoff, provenance):
        if packet.get("sourceReady") or packet.get("integrationAdmitted") or packet.get("rendererQuarantined") or packet.get("productionSelected"):
            raise ValueError("readiness boundary advanced")
    if not manifest.get("candidateReadyForIndependentReview") or not handoff.get("candidateReadyForIndependentReview"):
        raise ValueError("candidate readiness missing")
    for lod in manifest["lods"].values():
        if lod["mode"] != "RGBA" or lod["hiddenRgbPixels"] or lod["keyedMagentaPixels"] or lod["boundaryResidualChromaPixels"] or lod["frameEdgeOpaquePixels"]:
            raise ValueError("LOD mechanical gate failed")
    replay_sha = hashlib.sha256(json.dumps(replay_maps[0], sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    result = {
        "schema": "citysim.play-103.north-industrial-l01-v0.validation.v1",
        "task": "PLAY-103",
        "logicalId": "industrial_l01_v0",
        "direction": "north",
        "result": "PASS",
        "routeId": ROUTE_ID,
        "routeFileSha256": ROUTE_FILE_SHA,
        "routeCanonicalSha256": ROUTE_CANONICAL_SHA,
        "rawNorthSha256": EXPECTED_RAW,
        "rawDimensions": [1536, 1024],
        "lodCount": 3,
        "contactSheetCount": 3,
        "repeat": args.repeat,
        "freshProcesses": args.repeat,
        "replaysIdentical": True,
        "replaySha256": [replay_sha for _ in range(args.repeat)],
        "artifactTreeSha256": manifest["artifactTreeSha256"],
        "transport": TRANSPORT,
        "candidateReadyForIndependentReview": True,
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
        "visualAcceptance": "not_performed_worker_cannot_self_accept",
        "siblingInputsConsumed": [],
    }
    write_json(EVIDENCE, result)
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
