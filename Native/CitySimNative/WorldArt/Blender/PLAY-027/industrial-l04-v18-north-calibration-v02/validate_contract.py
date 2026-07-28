#!/usr/bin/env python3
"""Fail-closed no-render validator for the exact CONTRACT-020 calibration."""

import argparse
import hashlib
import json
import math
from pathlib import Path


EXPECTED_DESCRIPTOR_SHA = (
    "3696b813e6c3e0f46251e689582163bdbdcc5d84a3a9c1125bfbefba37da2630"
)
EXPECTED_MATERIAL_SHA = (
    "147c11d64be9fac934a6d4276a2e1a9d27f207bb1a1babd47222aaf5c2b3d202"
)
EXPECTED_EXECUTABLE_SHA = (
    "8485107307b16bd0899f3c259261494b0c80e383db239c04e2c9fcd14d305fb4"
)
EXPECTED_VERSION_SHA = (
    "df120979d2fbf1b7ea0bef4d944250746cc6077f871b0ee98b782a863ec7d2f9"
)
V01_CONFIG = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
    "industrial-l04-v18-north-calibration-v01/CALIBRATION-CONTRACT.json"
)
EXPECTED_V01_CONFIG_SHA = (
    "5653f34eb447237df1863b8d5f59b39d78c90611fc7bd5503e255691a870ba40"
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


def inside(root, relative):
    path = (root / relative).resolve()
    path.relative_to(root)
    return path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--config", required=True)
    parser.add_argument("--renderer-script", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    root = Path(args.repository_root).resolve()
    config_path = inside(root, args.config)
    script_path = inside(root, args.renderer_script)
    output_path = inside(root, args.output)
    config = json.loads(config_path.read_text(encoding="utf-8"))
    v01_config_path = inside(root, V01_CONFIG)
    v01_config = json.loads(v01_config_path.read_text(encoding="utf-8"))
    descriptor_path = inside(root, config["descriptor"]["file"])
    material_path = inside(root, config["materialLibrary"]["file"])
    version_path = inside(root, config["blender"]["versionFile"])
    executable_path = Path(config["blender"]["executable"]).resolve()
    descriptor = json.loads(descriptor_path.read_text(encoding="utf-8"))
    material_root = json.loads(material_path.read_text(encoding="utf-8"))
    descriptor_sha = digest(descriptor_path)
    material_sha = digest(material_path)
    executable_sha = digest(executable_path)
    version_sha = digest(version_path)
    require(descriptor_sha == EXPECTED_DESCRIPTOR_SHA, "descriptor SHA drift")
    require(material_sha == EXPECTED_MATERIAL_SHA, "material SHA drift")
    require(executable_sha == EXPECTED_EXECUTABLE_SHA, "Blender executable SHA drift")
    require(version_sha == EXPECTED_VERSION_SHA, "Blender version text SHA drift")
    require(
        digest(v01_config_path) == EXPECTED_V01_CONFIG_SHA,
        "v01 calibration contract drift",
    )
    require(config["descriptor"]["sha256"] == descriptor_sha, "descriptor binding")
    require(
        config["materialLibrary"]["sha256"] == material_sha,
        "material binding",
    )
    require(
        config["blender"]["executableSHA256"] == executable_sha,
        "executable binding",
    )
    require(
        config["blender"]["versionFileSHA256"] == version_sha,
        "version binding",
    )
    require(descriptor["logicalBuildingID"] == "industrial_l04", "logical ID")
    require(descriptor["variantID"] == "variant-0", "variant")
    require(descriptor["viewDirection"] == "n", "direction")
    require(descriptor["sourceRevision"] == "source-v18-prepixel", "revision")
    require(
        descriptor["sceneGeometryID"]
        == "industrial-l04-crucible-gantry-v18-north-single-foundation",
        "geometry ID",
    )
    require(
        descriptor["registration"]["orientationTransform"] == "none",
        "orientation",
    )
    require(descriptor["authoredIndependently"] is True, "authorship")
    require(descriptor["sourceAuthority"] is False, "source authority")
    require(descriptor["productionSelected"] is False, "production selection")
    require(
        descriptor["building"]["usesExplicitComponentGeometry"] is True,
        "explicit-component geometry",
    )
    require(descriptor["building"]["roofVolumes"] == [], "roof volumes")
    require(descriptor["building"]["trimBands"] == [], "trim bands")
    require(len(descriptor["building"]["massBlocks"]) == 39, "mass block count")
    require(len(descriptor["props"]) == 11, "prop count")
    require(
        all(prop["kind"] == "explicit-cylinder" for prop in descriptor["props"]),
        "prop kind",
    )
    materials = material_root["materials"]
    require(len(materials) == 13, "material count")
    material_ids = [item["id"] for item in materials]
    require(len(material_ids) == len(set(material_ids)), "material ID uniqueness")
    components = [
        {
            "nodeName": "foundation",
            "sourceKind": "foundation",
            "materialID": descriptor["building"]["foundationMaterialID"],
        }
    ]
    components += [
        {
            "nodeName": item["id"],
            "sourceKind": "massBlock",
            "materialID": item["materialID"],
        }
        for item in descriptor["building"]["massBlocks"]
    ]
    components += [
        {
            "nodeName": item["id"],
            "sourceKind": "prop",
            "materialID": item["materialID"],
        }
        for item in descriptor["props"]
    ]
    require(len(components) == 51, "rendered component count")
    names = [item["nodeName"] for item in components]
    require(len(names) == len(set(names)), "component name uniqueness")
    unresolved = sorted(
        {
            item["materialID"]
            for item in components
            if item["materialID"] not in material_ids
        }
    )
    require(not unresolved, f"unresolved materials: {unresolved}")
    require(
        descriptor["registration"]["groundPivotSource"] == [768, 896],
        "ground pivot",
    )
    require(
        descriptor["registration"]["frontageSocketSource"] == [896, 704],
        "frontage socket",
    )
    require(
        descriptor["registration"]["contactPolygonWorld"]
        == [[-28, -28], [28, -28], [28, 28], [-28, 28]],
        "contact polygon",
    )
    require(
        descriptor["light"]["keyOrigin"] == [-80, 120, -80],
        "northwest key",
    )
    require(
        descriptor["light"]["shadowVectorSource"] == [2, 1],
        "southeast shadow",
    )
    cycles = config["cycles"]
    require(cycles["device"] == "CPU", "Cycles CPU")
    require(cycles["threads"] == 1, "one thread")
    require(cycles["adaptiveSampling"] is False, "adaptive sampling disabled")
    require(cycles["denoising"] is False, "denoising disabled")
    require(cycles["motionBlur"] is False, "motion blur disabled")
    require(cycles["transparentFilm"] is True, "transparent film")
    require(config["blender"]["addons"] == [], "no add-ons")
    require(config["blender"]["networkAssets"] is False, "no network assets")
    require(config["blender"]["gpu"] is False, "no GPU")
    require("--factory-startup" in config["commandTemplate"], "factory startup")
    require("--disable-autoexec" in config["commandTemplate"], "autoexec disabled")
    require("--python-exit-code 1" in config["commandTemplate"], "exit code")
    require("--threads 1" in config["commandTemplate"], "command thread binding")
    repair = config["cameraRegistrationRepair"]
    viewport = descriptor["camera"]["renderViewportPixels"]
    aspect = float(viewport[0]) / float(viewport[1])
    expected_ortho = (
        2.0 * float(descriptor["camera"]["orthographicScale"]) * aspect
    )
    require(math.isclose(aspect, 1.5, abs_tol=1e-12), "camera aspect")
    require(
        math.isclose(
            float(repair["sceneKitOrthographicScale"]),
            float(descriptor["camera"]["orthographicScale"]),
            abs_tol=1e-12,
        ),
        "SceneKit orthographic scale binding",
    )
    require(
        math.isclose(float(repair["aspect"]), aspect, abs_tol=1e-12),
        "camera aspect binding",
    )
    require(
        math.isclose(
            float(repair["blenderOrthoScale"]),
            expected_ortho,
            abs_tol=1e-12,
        ),
        "Blender orthographic scale formula",
    )
    require(
        math.isclose(expected_ortho, 237.5878601074218, abs_tol=1e-12),
        "exact repaired orthographic scale",
    )
    require(repair["shiftX"] == 0, "shift x")
    require(repair["shiftY"] == 0.125, "shift y")
    require(repair["maximumProjectionErrorPixels"] == 1, "projection tolerance")
    require(repair["edgeContactAllowed"] is False, "edge-contact rejection")
    require(
        "--projection-proof-only" in config["projectionProofCommandTemplate"],
        "projection-only mode binding",
    )
    require(
        "--process-id PREPIXEL" in config["projectionProofCommandTemplate"],
        "projection process binding",
    )
    for field in ("descriptor", "materialLibrary", "comparisons", "expected", "cycles"):
        require(config[field] == v01_config[field], f"v01 {field} preservation")
    v01_blender = dict(v01_config["blender"])
    v02_blender = dict(config["blender"])
    v01_blender.pop("versionFile")
    v02_blender.pop("versionFile")
    require(v02_blender == v01_blender, "v01 Blender environment preservation")
    report = {
        "schema": 1,
        "task": "PLAY-027",
        "contract": "CONTRACT-020",
        "calibrationID": config["calibrationID"],
        "validationPassed": True,
        "blenderExecutableSHA256": executable_sha,
        "blenderVersionFileSHA256": version_sha,
        "configSHA256": digest(config_path),
        "predecessorConfigSHA256": digest(v01_config_path),
        "rendererScriptSHA256": digest(script_path),
        "descriptorSHA256": descriptor_sha,
        "materialLibrarySHA256": material_sha,
        "renderedComponentCount": len(components),
        "materialCount": len(materials),
        "componentNames": sorted(names),
        "unresolvedMaterialIDs": unresolved,
        "skippedByExplicitComponentContract": [
            "building.chimney",
            "facades",
            "entrance",
        ],
        "registration": {
            "groundPivotSource": descriptor["registration"]["groundPivotSource"],
            "frontageSocketSource": descriptor["registration"][
                "frontageSocketSource"
            ],
            "footprintPolygonSource": descriptor["registration"][
                "footprintPolygonSource"
            ],
            "contactPolygonWorld": descriptor["registration"][
                "contactPolygonWorld"
            ],
            "northwestKeyOriginWorld": descriptor["light"]["keyOrigin"],
            "southeastShadowVectorSource": descriptor["light"][
                "shadowVectorSource"
            ],
        },
        "cameraRegistrationRepair": repair,
        "predecessorPreservation": {
            "descriptor": True,
            "materialLibrary": True,
            "comparisons": True,
            "expectedRegistrationAndCounts": True,
            "cycles": True,
            "blenderEnvironmentExceptSuccessorVersionFilePath": True,
        },
        "cycles": cycles,
        "rawRendererProcessCount": 0,
        "sceneKitProcessCount": 0,
        "normalizerProcessCount": 0,
        "sourceAuthority": False,
        "productionSelected": False,
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(canonical(report))


if __name__ == "__main__":
    main()
