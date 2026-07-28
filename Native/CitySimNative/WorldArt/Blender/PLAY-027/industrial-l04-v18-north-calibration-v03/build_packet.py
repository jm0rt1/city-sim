#!/usr/bin/env python3
"""Bind the exact CONTRACT-020 R3 North calibration evidence packet."""

import argparse
import hashlib
import json
from pathlib import Path


EXPECTED_DESCRIPTOR = (
    "3696b813e6c3e0f46251e689582163bdbdcc5d84a3a9c1125bfbefba37da2630"
)
EXPECTED_MATERIAL = (
    "147c11d64be9fac934a6d4276a2e1a9d27f207bb1a1babd47222aaf5c2b3d202"
)
EXPECTED_BLENDER = (
    "8485107307b16bd0899f3c259261494b0c80e383db239c04e2c9fcd14d305fb4"
)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical(value):
    return (
        json.dumps(value, indent=2, sort_keys=True, separators=(",", ": "))
        + "\n"
    ).encode("utf-8")


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    root = Path(args.repository_root).resolve()
    output = (root / args.output).resolve()
    output.relative_to(root)
    base = (
        root
        / "docs/production/evidence/PLAY-027/industrial-l04/l04"
        / "blender-v18-north-calibration-v03"
    )
    raw_identity_path = base / "diagnostics/RAW-IDENTITY.json"
    semantic_identity_path = base / "diagnostics/SEMANTIC-IDENTITY.json"
    raw_identity = json.loads(raw_identity_path.read_text())
    semantic_identity = json.loads(semantic_identity_path.read_text())
    require(raw_identity["validationPassed"] is True, "raw identity gate")
    require(
        raw_identity["decodedRGBAIdentity"] is True,
        "raw decoded identity",
    )
    require(
        semantic_identity["validationPassed"] is True,
        "semantic identity gate",
    )
    require(
        semantic_identity["decodedRGBAIdentity"] is True,
        "semantic decoded identity",
    )

    runs = []
    mapping_hashes = []
    projection_hashes = []
    for process_id in ("A", "B", "C"):
        run_dir = base / "diagnostics" / f"run-{process_id.lower()}"
        provenance_path = run_dir / "provenance.json"
        mapping_path = run_dir / "object-mapping.json"
        projection_path = run_dir / "PROJECTION-PROOF.json"
        provenance = json.loads(provenance_path.read_text())
        mapping = json.loads(mapping_path.read_text())
        projection = json.loads(projection_path.read_text())
        require(provenance["processID"] == process_id, "process identity")
        require(
            provenance["renderedComponentCount"] == 51,
            "component count",
        )
        require(
            provenance["inputs"]["descriptorSHA256"] == EXPECTED_DESCRIPTOR,
            "descriptor binding",
        )
        require(
            provenance["inputs"]["materialLibrarySHA256"] == EXPECTED_MATERIAL,
            "material binding",
        )
        require(
            provenance["blender"]["executableSHA256"] == EXPECTED_BLENDER,
            "Blender executable binding",
        )
        require(mapping["renderedComponentCount"] == 51, "mapping count")
        require(len(mapping["components"]) == 51, "mapping components")
        require(projection["projectionPassed"] is True, "projection gate")
        mapping_hashes.append(digest(mapping_path))
        projection_hashes.append(digest(projection_path))
        runs.append(
            {
                "processID": process_id,
                "rawPNG": str(
                    (run_dir / "raw.png").relative_to(root)
                ),
                "rawFileSHA256": digest(run_dir / "raw.png"),
                "rawDecodedPremultipliedRGBASHA256":
                    raw_identity["sources"][ord(process_id) - ord("A")][
                        "decodedPremultipliedRGBASHA256"
                    ],
                "semanticPNG": str(
                    (run_dir / "semantic.png").relative_to(root)
                ),
                "semanticFileSHA256": digest(run_dir / "semantic.png"),
                "semanticDecodedPremultipliedRGBASHA256":
                    semantic_identity["sources"][ord(process_id) - ord("A")][
                        "decodedPremultipliedRGBASHA256"
                    ],
                "objectMappingSHA256": digest(mapping_path),
                "projectionProofSHA256": digest(projection_path),
                "provenanceSHA256": digest(provenance_path),
                "occupiedBounds":
                    raw_identity["sources"][ord(process_id) - ord("A")][
                        "metrics"
                    ]["alphaBounds"],
            }
        )
    require(len(set(mapping_hashes)) == 1, "object mapping identity")
    require(len(set(projection_hashes)) == 1, "projection proof identity")

    review = base / "review"
    panels = []
    for path in sorted(review.glob("*.png")):
        panels.append(
            {
                "file": str(path.relative_to(root)),
                "sha256": digest(path),
            }
        )
    require(len(panels) == 11, "review panel count")
    result = {
        "schema": 1,
        "task": "PLAY-027",
        "contract": "CONTRACT-020",
        "calibrationID":
            "industrial-l04-v18-north-blender-cycles-calibration-v03",
        "disposition": "PENDING_INDEPENDENT_RENDERER_QA_REVIEW",
        "prepixelCheckpoint": "PENDING_V03_PREPIXEL_COMMIT",
        "processCount": 3,
        "runs": runs,
        "decodedRGBAIdentity": True,
        "rawPNGContainerIdentity": raw_identity["fileIdentity"],
        "rawPNGContainerIdentityRequired": False,
        "occupiedBoundsIdentity": len(
            {tuple(run["occupiedBounds"]) for run in runs}
        ) == 1,
        "objectMappingIdentity": len(set(mapping_hashes)) == 1,
        "projectionProofIdentity": len(set(projection_hashes)) == 1,
        "renderedComponentCount": 51,
        "materialCount": 13,
        "descriptorSHA256": EXPECTED_DESCRIPTOR,
        "materialLibrarySHA256": EXPECTED_MATERIAL,
        "blenderExecutableSHA256": EXPECTED_BLENDER,
        "rawIdentityReportSHA256": digest(raw_identity_path),
        "semanticIdentityReportSHA256": digest(semantic_identity_path),
        "taskOwnedToolSources": {
            "rendererImporterSHA256": digest(
                Path(__file__).parent / "render_v18_north.py"
            ),
            "rawValidatorSHA256": digest(
                Path(__file__).parent / "ValidateBlenderCalibrationRaw.swift"
            ),
            "reviewBuilderSHA256": digest(
                Path(__file__).parent / "BuildBlenderCalibrationReview.swift"
            ),
            "packetBuilderSHA256": digest(Path(__file__)),
        },
        "reviewPanels": panels,
        "sceneKitProcessCount": 0,
        "normalizerProcessCount": 0,
        "siblingDirectionProcessCount": 0,
        "sourceAuthority": False,
        "productionSelected": False,
    }
    require(result["occupiedBoundsIdentity"], "occupied bounds identity")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(canonical(result))


if __name__ == "__main__":
    main()
