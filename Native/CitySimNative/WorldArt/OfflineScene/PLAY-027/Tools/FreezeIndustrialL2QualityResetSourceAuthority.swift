import CryptoKit
import Foundation

enum QualityResetSourceFreezeError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: freeze-industrial-l2-quality-reset-source-authority --repository-root <path>"
        case let .invalid(message):
            return message
        }
    }
}

private let approvedDesignHashes = [
    "north": "83c4bb6b8437f44b9c25b168395725c788b6f7326d6595d7404882090e1a3596",
    "east": "46896f6c9aae7e37e682d6137cfaec7d35c706f4222bedece9be7127ff9d0265",
    "south": "b6e5df380e17cd10c08394e844066fe2e4e25f4e181484b178172ea0663f0185",
    "west": "57a150395f4c073b77fc4eeecc4d246e9b3c00e81ec87661383e8c120faabbc3",
]

private let approvedGeometryHashes = [
    "north": "7bae82334de9b3dfad0a10217dd4109e536385354275ef0566c86de7c155c313",
    "east": "03fa84eb21231bb191887bccd45e5c22ed9d4739b8325b4bb89411bd56bb57b9",
    "south": "01e74e25fcb06002e369973c4ccbb831e36cf03a6c34cc03752927225fcf2277",
    "west": "72728a3e3fec588a27a4d3dfa8cc212c5d388ede8ae67759dbe7aab1701a9d2c",
]

private let approvedComponentCounts = [
    "north": 45,
    "east": 43,
    "south": 41,
    "west": 46,
]

private let approvedMaterialLibraryHash =
    "cbe08743f146ccb522e67df3525171da4ab2cc7912ea37431d4c2ef921ca5570"
private let approvedToolchainHash =
    "a240a1a501c6fa30c5bd4b2d6303aac4547fd7a7416649ff8fd0d58f9729341e"
private let paintedSteelTextureHash =
    "cdff5e3f387a9efaea845eae44ff6bf6841a2b8d440f3796a060c624259056fb"
private let roofMembraneTextureHash =
    "c5e6c30df2cf266303bdf69c2017de4d67898f5ef6ddcc1481316b6f9ee421f2"
private let rejectedConcreteTextureHash =
    "1b5e9218fedca7f6c317bb948dfdbb33491ced17f6bcdbc1fa8cd7f91560b8ec"
private let rejectedCorrugatedTextureHash =
    "3f7c964486be97b19fca79b8f48333ee9c059f338e70cfb34a1ac2c1205ee105"

private func argument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw QualityResetSourceFreezeError.arguments
    }
    return arguments[index + 1]
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func sha256(_ url: URL) throws -> String {
    sha256(try Data(contentsOf: url))
}

private func relative(
    _ url: URL,
    repositoryRoot: URL
) -> String {
    let prefix = repositoryRoot.path + "/"
    guard url.path.hasPrefix(prefix) else { return url.path }
    return String(url.path.dropFirst(prefix.count))
}

private func jsonObject(_ url: URL) throws -> [String: Any] {
    guard
        let object = try JSONSerialization.jsonObject(
            with: Data(contentsOf: url)
        ) as? [String: Any]
    else {
        throw QualityResetSourceFreezeError.invalid(
            "could not decode JSON object: \(url.path)"
        )
    }
    return object
}

private func writeJSON(
    _ object: Any,
    to url: URL
) throws {
    var data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: url, options: .atomic)
}

private func samplingBlock() -> [String: Any] {
    [
        "contractID": "play027-deterministic-4x-no-msaa-lanczos-v3",
        "sourceRevisionBinding": "source-v09",
        "purpose": "source-authority",
        "sceneKitAntialiasing": "none",
        "sceneKitShadows": "current",
        "sceneKitLightingMode": "lambert-scene-lights",
        "linearOversamplingFactor": 4,
        "downsample": [
            "filter": "CILanczosScaleTransform",
            "scale": 0.25,
            "aspectRatio": 1,
        ],
        "ciContext": [
            "useSoftwareRenderer": true,
            "cacheIntermediates": false,
            "workingColorSpace": "extended-srgb",
            "outputColorSpace": "srgb",
        ],
        "quantizer": [
            "id": "step32-midpoint-offset8-v1",
            "step": 32,
            "midpointOffset": 8,
            "chromaBypassRGBA": [255, 0, 255, 255],
        ],
        "canonicalizer": [
            "id": "imageio-sips-png-v1",
            "encoder": "ImageIO",
            "postEncoder": "/usr/bin/sips",
            "format": "png",
        ],
        "postQuantizationCanonicalizer": [
            "algorithm": "opaque-isolated-one-quantum-majority-3x3",
            "version": 3,
            "quantizationQuantum": 32,
            "neighborhoodSize": 3,
            "majorityThreshold": 7,
            "requiresFullyOpaqueNeighborhood": true,
            "immutableSourceBuffer": true,
            "requiresChromaFreeNeighborhood": true,
            "channels": "rgb-only",
            "preservesAlpha": true,
            "preservesChroma": true,
            "boundaryAssist": [
                "algorithm":
                    "immutable-prequantized-one-value-boundary-6-plus-1",
                "version": 1,
                "baseQuantizedMajorityCount": 6,
                "requiredBoundaryVoteCount": 1,
                "effectiveSupportCount": 7,
                "maximumCompetingSupportAfterBoundaryReclassification": 2,
                "quantizerStep": 32,
                "quantizerMidpointOffset": 8,
                "boundaryBandWidthValues": 1,
                "requiresSameChannelEvidence": true,
                "immutablePrequantizedBuffer": true,
                "recordsBoundaryVoteReason": true,
            ],
        ],
    ]
}

private func sourceMaterialLibrary(
    from approved: [String: Any]
) throws -> [String: Any] {
    guard let materials = approved["materials"] as? [[String: Any]] else {
        throw QualityResetSourceFreezeError.invalid(
            "approved material roles are missing"
        )
    }
    let mappedMaterials = try materials.map { source -> [String: Any] in
        guard
            let id = source["id"] as? String,
            let color = source["baseColorRGBA"] as? [Double],
            let roughness = source["roughness"] as? Double,
            let metalness = source["metalness"] as? Double,
            let pattern = source["pattern"] as? String,
            let physicalScale = source["physicalScaleWorld"] as? [Double],
            let disposition = source["sourceSwatchDisposition"] as? String
        else {
            throw QualityResetSourceFreezeError.invalid(
                "malformed approved material role"
            )
        }
        var material: [String: Any] = [
            "id": id,
            "baseColorRGBA": color,
            "roughness": roughness,
            "metalness": metalness,
            "pattern": pattern,
            "physicalScaleWorld": physicalScale,
            "textureMapping": [
                "mode": "world-scale-box-face-repeat-v1",
                "wrapS": "repeat",
                "wrapT": "repeat",
                "minificationFilter": "linear",
                "magnificationFilter": "linear",
                "mipFilter": "linear",
            ],
        ]
        if disposition == "accepted-for-prepixel-material-reference" {
            guard
                let swatch = source["sourceSwatch"] as? [String: Any],
                let file = swatch["file"] as? String,
                let hash = swatch["sha256"] as? String,
                [paintedSteelTextureHash, roofMembraneTextureHash]
                    .contains(hash)
            else {
                throw QualityResetSourceFreezeError.invalid(
                    "accepted material role does not bind an approved swatch"
                )
            }
            material["sourceTexture"] = [
                "role": id == "dark-roof-membrane"
                    ? "seam-passing-dark-roof-membrane"
                    : "seam-passing-blue-gray-painted-steel",
                "file": file,
                "sha256": hash,
            ]
        } else if
            let swatch = source["sourceSwatch"] as? [String: Any],
            let hash = swatch["sha256"] as? String,
            [rejectedConcreteTextureHash, rejectedCorrugatedTextureHash]
                .contains(hash)
        {
            // The approved rejected rasters remain evidence-only. This
            // production material intentionally carries no sourceTexture.
        }
        return material
    }

    return [
        "schema": 1,
        "task": "PLAY-027",
        "libraryID": "industrial-l02-quality-reset-source-v09-materials",
        "source":
            "component-traceable quality-reset roles; procedural concrete and corrugation plus two seam-passing governed ImageGen swatches",
        "styleAnchorFile":
            "Native/CitySimNative/WorldArt/GateA/golden_district_imagegen_source-v2.png",
        "styleAnchorSHA256":
            "b227286bfe5ffe8cfc920d3faf8abe081f5cca8a498c215bfb8a840a448e7425",
        "familyAnchorFile":
            "Native/CitySimNative/WorldArt/GeneratedV4/ImageGen/raw/calibration/industrial_l01/source-v01.png",
        "familyAnchorSHA256":
            "22dbf75f35d66f86b108c8e5ab9d7b3f753df74489d0b9e9877fc81ba86a2515",
        "imageGenMaterialSwatchesUsed": true,
        "colorSpace": "extended-sRGB",
        "materials": mappedMaterials,
        "productionSelected": false,
    ]
}

private func facadeEdges() -> [String: [[Double]]] {
    [
        "north": [[-28, -28], [28, -28]],
        "east": [[28, -28], [28, 28]],
        "south": [[28, 28], [-28, 28]],
        "west": [[-28, 28], [-28, -28]],
    ]
}

private func doorBaseSource() -> [String: [[Double]]] {
    [
        "north": [[858, 685], [934, 723]],
        "east": [[934, 813], [858, 851]],
        "south": [[678, 851], [602, 813]],
        "west": [[602, 723], [678, 685]],
    ]
}

private func entranceBase(_ direction: String) -> [Double] {
    switch direction {
    case "north": return [0, 3, -28]
    case "east": return [28, 3, 0]
    case "south": return [0, 3, 28]
    default: return [-28, 3, 0]
    }
}

private func sourceScene(
    from design: [String: Any],
    direction: String,
    materialFile: String,
    materialHash: String,
    toolchainFile: String
) throws -> ([String: Any], [[String: Any]]) {
    guard
        let registration = design["registration"] as? [String: Any],
        var camera = design["camera"] as? [String: Any],
        let designLight = design["light"] as? [String: Any],
        let components = design["components"] as? [[String: Any]],
        let geometryID = design["sceneGeometryID"] as? String,
        components.count == approvedComponentCounts[direction]
    else {
        throw QualityResetSourceFreezeError.invalid(
            "approved \(direction) design is malformed"
        )
    }
    guard
        let foundation = components.first(
            where: { ($0["category"] as? String) == "foundation" }
        ),
        let foundationDimensions = foundation["dimensions"] as? [Double],
        let foundationPosition = foundation["positionWorld"] as? [Double],
        let foundationMaterial = foundation["materialRole"] as? String
    else {
        throw QualityResetSourceFreezeError.invalid(
            "\(direction) foundation component is missing"
        )
    }

    var massBlocks: [[String: Any]] = []
    var props: [[String: Any]] = []
    var trace: [[String: Any]] = []
    for component in components {
        guard
            let id = component["id"] as? String,
            let primitive = component["primitive"] as? String,
            let position = component["positionWorld"] as? [Double],
            let dimensions = component["dimensions"] as? [Double],
            let material = component["materialRole"] as? String
        else {
            throw QualityResetSourceFreezeError.invalid(
                "\(direction) contains a malformed component"
            )
        }
        if id == foundation["id"] as? String {
            trace.append([
                "approvedComponentID": id,
                "productionOwner": "building.foundation",
                "primitive": primitive,
                "positionWorld": position,
                "dimensions": dimensions,
                "materialRole": material,
            ])
        } else if primitive == "box" {
            massBlocks.append([
                "id": id,
                "positionWorld": position,
                "dimensions": dimensions,
                "materialID": material,
            ])
            trace.append([
                "approvedComponentID": id,
                "productionOwner": "building.massBlocks.\(id)",
                "primitive": primitive,
                "positionWorld": position,
                "dimensions": dimensions,
                "materialRole": material,
            ])
        } else if primitive == "cylinder" {
            props.append([
                "id": id,
                "kind": "explicit-cylinder",
                "positionWorld": position,
                "dimensions": dimensions,
                "materialID": material,
            ])
            trace.append([
                "approvedComponentID": id,
                "productionOwner": "props.\(id)",
                "primitive": primitive,
                "positionWorld": position,
                "dimensions": dimensions,
                "materialRole": material,
            ])
        } else {
            throw QualityResetSourceFreezeError.invalid(
                "\(direction) contains unsupported primitive \(primitive)"
            )
        }
    }
    guard trace.count == components.count else {
        throw QualityResetSourceFreezeError.invalid(
            "\(direction) component trace is incomplete"
        )
    }

    camera["oversamplingFactor"] = 4
    var sourceRegistration = registration
    sourceRegistration["sceneFootprintUnits"] = [72, 72]
    sourceRegistration["doorBaseSource"] = doorBaseSource()[direction]
    sourceRegistration["presentationEnvelopeSource"] = [256, 40, 1280, 896]
    sourceRegistration["shadowEnvelopeSource"] = [768, 512, 1456, 976]

    var light = designLight
    light["shadowVectorSource"] = [2, 1]
    light["shadowOpacity"] = 0.34
    light["shadowBlurSourcePixels"] = 18
    light["shadowReceiver"] = "task-owned-transparent-ground-plane"
    light.removeValue(forKey: "authoredContactShadowDirection")

    let edges = facadeEdges()
    let facades = ["north", "east", "south", "west"].map { facade in
        [
            "id": "\(facade)-facade",
            "direction": facade,
            "edgeWorld": edges[facade]!,
            "materialID": "blue-gray-painted-steel",
            "hasEntrance": facade == direction,
            "windowBays": [],
            "windowRhythms": [],
        ] as [String: Any]
    }

    let scene: [String: Any] = [
        "schema": 2,
        "task": "PLAY-027",
        "sceneGeometryID": geometryID,
        "logicalBuildingID": "industrial_l02",
        "family": "industrial",
        "level": 2,
        "variantID": "variant-0",
        "viewDirection": direction,
        "sourceRevision": "source-v09",
        "authoredIndependently": true,
        "productionSelected": false,
        "derivation": [
            "sourceKind": "independent-scene-description",
            "siblingSource": NSNull(),
            "mirror": false,
            "rotationDegrees": 0,
            "transform": "none",
        ],
        "toolchainFingerprint": [
            "role":
                "frozen-schema-2-v3-quality-reset-offline-host-and-frameworks",
            "file": toolchainFile,
            "sha256": approvedToolchainHash,
        ],
        "styleAnchor": [
            "role": "immutable-appearance-only-global-style-anchor",
            "file":
                "Native/CitySimNative/WorldArt/GateA/golden_district_imagegen_source-v2.png",
            "sha256":
                "b227286bfe5ffe8cfc920d3faf8abe081f5cca8a498c215bfb8a840a448e7425",
        ],
        "materialLibrary": [
            "role":
                "industrial-l02-quality-reset-world-scale-material-roles",
            "file": materialFile,
            "sha256": materialHash,
        ],
        "registration": sourceRegistration,
        "camera": camera,
        "sampling": samplingBlock(),
        "light": light,
        "building": [
            "width": 56,
            "depth": 56,
            "foundationHeight": foundationDimensions[1],
            "floorHeight": 12,
            "floors": 3,
            "wallHeight": 48,
            "roofHeight": 2.2,
            "roofOverhang": 0,
            "wallMaterialID": "blue-gray-painted-steel",
            "trimMaterialID": "painted-structural-steel",
            "roofMaterialID": "dark-roof-membrane",
            "foundationMaterialID": foundationMaterial,
            "foundationDimensions": foundationDimensions,
            "foundationPositionWorld": foundationPosition,
            "chimney": [
                "positionWorld": [0, 1, 0],
                "dimensions": [1, 1, 1],
                "materialID": "galvanized-service-metal",
            ],
            "massingProfile":
                "medium-logistics-manufacturing-quality-reset-v01",
            "massBlocks": massBlocks,
            "roofVolumes": [],
            "trimBands": [],
            "usesLegacyDomesticDetails": false,
            "usesExplicitComponentGeometry": true,
        ],
        "facades": facades,
        "entrance": [
            "facadeID": "\(direction)-facade",
            "baseWorld": entranceBase(direction),
            "width": 24,
            "height": 15,
            "depth": 2,
            "doorMaterialID": "sectional-loading-door",
            "surroundMaterialID": "painted-structural-steel",
            "stepCount": 1,
            "stepRun": 2,
            "canopyDepth": 10,
            "hingeSide": "right",
            "pavilionWidth": 30,
            "pavilionDepth": 8,
            "pavilionHeight": 24,
            "pavilionRoofHeight": 3,
            "pavilionMaterialID": "painted-structural-steel",
            "porchWidth": 30,
            "porchColumnWidth": 1.4,
            "porchLateralOffset": 0,
            "style": "explicit-component-frontage",
        ],
        "props": props,
        "occlusionExclusions": [
            [
                "id": "\(direction)-quality-reset-loading-clearance",
                "purpose":
                    "protect the exact three-dock frontage, grounded portal, service apron, and road socket",
                "polygonWorld": direction == "north"
                    ? [[-28, -52], [28, -52], [28, -14], [-28, -14]]
                    : direction == "east"
                        ? [[14, -28], [52, -28], [52, 28], [14, 28]]
                        : direction == "south"
                            ? [[-28, 14], [28, 14], [28, 52], [-28, 52]]
                            : [[-52, -28], [-14, -28], [-14, 28], [-52, 28]],
            ],
        ],
    ]
    return (scene, trace)
}

@main
enum FreezeIndustrialL2QualityResetSourceAuthorityMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try argument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let evidenceRoot = repositoryRoot.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/quality-reset-prepixel-v01"
        )
        let approvedMaterialURL = evidenceRoot.appendingPathComponent(
            "materials/industrial-l02-quality-reset-v01-materials.json"
        )
        guard try sha256(approvedMaterialURL) == approvedMaterialLibraryHash
        else {
            throw QualityResetSourceFreezeError.invalid(
                "approved material library hash drift"
            )
        }
        let approvedMaterials = try jsonObject(approvedMaterialURL)
        let materialURL = repositoryRoot.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/materials/industrial-l02-quality-reset-source-v09-materials.json"
        )
        try writeJSON(
            try sourceMaterialLibrary(from: approvedMaterials),
            to: materialURL
        )
        let materialHash = try sha256(materialURL)
        let toolchainURL = repositoryRoot.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/toolchain/toolchain-industrial-l02-quality-reset-source-v09.json"
        )
        guard try sha256(toolchainURL) == approvedToolchainHash else {
            throw QualityResetSourceFreezeError.invalid(
                "toolchain fingerprint hash drift"
            )
        }

        let sourceRoot = repositoryRoot.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/source-authority/quality-reset-v01/scenes"
        )
        var traceRecords: [[String: Any]] = []
        var descriptorRecords: [[String: Any]] = []
        for direction in ["north", "east", "south", "west"] {
            let designURL = evidenceRoot.appendingPathComponent(
                "descriptors/\(direction)/scene-design.json"
            )
            guard try sha256(designURL) == approvedDesignHashes[direction]
            else {
                throw QualityResetSourceFreezeError.invalid(
                    "approved \(direction) descriptor hash drift"
                )
            }
            let design = try jsonObject(designURL)
            let (scene, trace) = try sourceScene(
                from: design,
                direction: direction,
                materialFile: relative(
                    materialURL,
                    repositoryRoot: repositoryRoot
                ),
                materialHash: materialHash,
                toolchainFile: relative(
                    toolchainURL,
                    repositoryRoot: repositoryRoot
                )
            )
            let sceneURL = sourceRoot
                .appendingPathComponent("industrial_l02")
                .appendingPathComponent("variant-0")
                .appendingPathComponent(direction)
                .appendingPathComponent("scene.json")
            try writeJSON(scene, to: sceneURL)
            descriptorRecords.append([
                "direction": direction,
                "approvedDesignDescriptorFile":
                    relative(designURL, repositoryRoot: repositoryRoot),
                "approvedDesignDescriptorSHA256":
                    approvedDesignHashes[direction]!,
                "approvedGeometrySHA256":
                    approvedGeometryHashes[direction]!,
                "sourceDescriptorFile":
                    relative(sceneURL, repositoryRoot: repositoryRoot),
                "sourceDescriptorSHA256": try sha256(sceneURL),
                "sceneGeometryID": scene["sceneGeometryID"]!,
                "componentCount": trace.count,
                "productionSelected": false,
            ])
            traceRecords.append([
                "direction": direction,
                "approvedDesignDescriptorSHA256":
                    approvedDesignHashes[direction]!,
                "approvedGeometrySHA256":
                    approvedGeometryHashes[direction]!,
                "componentCount": trace.count,
                "components": trace,
            ])
        }
        guard
            Set(
                descriptorRecords.compactMap {
                    $0["sourceDescriptorSHA256"] as? String
                }
            ).count == 4,
            Set(
                descriptorRecords.compactMap {
                    $0["sceneGeometryID"] as? String
                }
            ).count == 4
        else {
            throw QualityResetSourceFreezeError.invalid(
                "direction descriptor/geometry uniqueness failed"
            )
        }

        let outputRoot = repositoryRoot.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/quality-reset-source-v09-prepixel"
        )
        try writeJSON(
            [
                "schema": 1,
                "task": "PLAY-027",
                "sourceRevision": "source-v09",
                "approvedDesignRevision": "quality-reset-prepixel-v01",
                "productionSelected": false,
                "descriptors": descriptorRecords,
                "materialLibrary": [
                    "file": relative(
                        materialURL,
                        repositoryRoot: repositoryRoot
                    ),
                    "sha256": materialHash,
                    "approvedDesignLibrarySHA256":
                        approvedMaterialLibraryHash,
                    "directRasterTextureSHA256": [
                        paintedSteelTextureHash,
                        roofMembraneTextureHash,
                    ],
                    "rejectedDirectTilesExcluded": [
                        rejectedConcreteTextureHash,
                        rejectedCorrugatedTextureHash,
                    ],
                ],
                "toolchainFingerprint": [
                    "file": relative(
                        toolchainURL,
                        repositoryRoot: repositoryRoot
                    ),
                    "sha256": approvedToolchainHash,
                ],
                "sampling": [
                    "schema": 2,
                    "contract": "v3",
                    "sceneKitMSAA": "none",
                    "linearOversamplingFactor": 4,
                    "softwareLanczosScale": 0.25,
                    "preLanczosCanonicalization": NSNull(),
                    "finiteEquivalenceTable": NSNull(),
                ],
                "passed": true,
            ],
            to: outputRoot.appendingPathComponent(
                "SOURCE-AUTHORITY-FREEZE.json"
            )
        )
        try writeJSON(
            [
                "schema": 1,
                "task": "PLAY-027",
                "sourceRevision": "source-v09",
                "purpose":
                    "component-for-component approved-design to source-authority trace",
                "records": traceRecords,
                "passed": true,
            ],
            to: outputRoot.appendingPathComponent(
                "COMPONENT-TRACEABILITY.json"
            )
        )
    }
}
