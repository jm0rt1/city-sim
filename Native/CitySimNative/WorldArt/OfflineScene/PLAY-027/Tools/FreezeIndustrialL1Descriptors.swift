import CryptoKit
import Foundation

enum FreezeIndustrialError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: freeze-industrial-l1-descriptors --repository-root <path> --manifest <json>"
        case let .invalid(message):
            return message
        }
    }
}

func industrialArgument(_ name: String, in arguments: [String]) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw FreezeIndustrialError.arguments
    }
    return arguments[index + 1]
}

func industrialSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func industrialRelative(_ url: URL, root: URL) -> String {
    let prefix = root.path + "/"
    return url.path.hasPrefix(prefix)
        ? String(url.path.dropFirst(prefix.count))
        : url.path
}

func industrialSampling() -> [String: Any] {
    [
        "contractID": "play027-deterministic-4x-no-msaa-lanczos-v3",
        "sourceRevisionBinding": "source-v01",
        "purpose": "source-authority",
        "sceneKitAntialiasing": "none",
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
                "algorithm": "immutable-prequantized-one-value-boundary-6-plus-1",
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

func industrialFacade(
    scene: String,
    direction: String,
    hasEntrance: Bool,
    centers: [[Double]]
) -> [String: Any] {
    let edges: [String: [[Double]]] = [
        "north": [[-28, -28], [28, -28]],
        "east": [[28, -28], [28, 28]],
        "south": [[28, 28], [-28, 28]],
        "west": [[-28, 28], [-28, -28]],
    ]
    return [
        "id": "\(direction)-facade",
        "direction": direction,
        "edgeWorld": edges[direction]!,
        "materialID": "corrugated-steel-sage",
        "hasEntrance": hasEntrance,
        "windowBays": [],
        "windowRhythms": [
            [
                "id": "\(scene)-\(direction)-clerestory",
                "centersWorld": centers,
                "width": 7,
                "height": 5.5,
                "sillHeight": 18,
                "floor": 1,
                "materialID": "industrial-glass",
            ]
        ],
    ]
}

func industrialFacades(_ direction: String) throws -> [[String: Any]] {
    switch direction {
    case "north":
        return [
            industrialFacade(scene: "n", direction: "north", hasEntrance: true,
                centers: [[-17, 23.5, -25.7], [17, 23.5, -25.7]]),
            industrialFacade(scene: "n", direction: "east", hasEntrance: false,
                centers: [[25.7, 23.5, -16], [25.7, 23.5, 0], [25.7, 23.5, 16]]),
            industrialFacade(scene: "n", direction: "south", hasEntrance: false,
                centers: [[18, 23.5, 25.7], [5, 23.5, 25.7], [-9, 23.5, 25.7], [-20, 23.5, 25.7]]),
            industrialFacade(scene: "n", direction: "west", hasEntrance: false,
                centers: [[-25.7, 23.5, 15], [-25.7, 23.5, 0], [-25.7, 23.5, -17]]),
        ]
    case "east":
        return [
            industrialFacade(scene: "e", direction: "north", hasEntrance: false,
                centers: [[-19, 23.5, -25.7], [-4, 23.5, -25.7], [15, 23.5, -25.7]]),
            industrialFacade(scene: "e", direction: "east", hasEntrance: true,
                centers: [[25.7, 23.5, -17], [25.7, 23.5, 17]]),
            industrialFacade(scene: "e", direction: "south", hasEntrance: false,
                centers: [[19, 23.5, 25.7], [3, 23.5, 25.7], [-14, 23.5, 25.7]]),
            industrialFacade(scene: "e", direction: "west", hasEntrance: false,
                centers: [[-25.7, 23.5, 18], [-25.7, 23.5, 5], [-25.7, 23.5, -9], [-25.7, 23.5, -20]]),
        ]
    case "south":
        return [
            industrialFacade(scene: "s", direction: "north", hasEntrance: false,
                centers: [[-18, 23.5, -25.7], [-5, 23.5, -25.7], [9, 23.5, -25.7], [20, 23.5, -25.7]]),
            industrialFacade(scene: "s", direction: "east", hasEntrance: false,
                centers: [[25.7, 23.5, -15], [25.7, 23.5, 1], [25.7, 23.5, 18]]),
            industrialFacade(scene: "s", direction: "south", hasEntrance: true,
                centers: [[17, 23.5, 25.7], [-17, 23.5, 25.7]]),
            industrialFacade(scene: "s", direction: "west", hasEntrance: false,
                centers: [[-25.7, 23.5, 17], [-25.7, 23.5, 0], [-25.7, 23.5, -16]]),
        ]
    case "west":
        return [
            industrialFacade(scene: "w", direction: "north", hasEntrance: false,
                centers: [[-18, 23.5, -25.7], [-3, 23.5, -25.7], [14, 23.5, -25.7]]),
            industrialFacade(scene: "w", direction: "east", hasEntrance: false,
                centers: [[25.7, 23.5, -18], [25.7, 23.5, -5], [25.7, 23.5, 9], [25.7, 23.5, 20]]),
            industrialFacade(scene: "w", direction: "south", hasEntrance: false,
                centers: [[18, 23.5, 25.7], [2, 23.5, 25.7], [-15, 23.5, 25.7]]),
            industrialFacade(scene: "w", direction: "west", hasEntrance: true,
                centers: [[-25.7, 23.5, 17], [-25.7, 23.5, -17]]),
        ]
    default:
        throw FreezeIndustrialError.invalid("invalid direction \(direction)")
    }
}

func industrialDirectionData(_ direction: String) throws -> (
    entranceBase: [Double],
    lateralOffset: Double,
    props: [[String: Any]],
    exclusion: [[Double]]
) {
    switch direction {
    case "north":
        return (
            [0, 2, -28], 10,
            [
                ["id": "north-rooftop-hvac", "kind": "rooftop-hvac", "positionWorld": [11, 42.2, 9], "dimensions": [10, 7, 9], "materialID": "rooftop-metal"],
                ["id": "north-exhaust-stack", "kind": "exhaust-stack", "positionWorld": [-12, 44.1, 10], "dimensions": [4.5, 17, 4.5], "materialID": "exhaust-dark"],
                ["id": "north-service-tank", "kind": "service-tank", "positionWorld": [21, 6.2, 18], "dimensions": [8, 12, 8], "materialID": "tank-oxide"],
            ],
            [[-24, -50], [26, -50], [26, -20], [-24, -20]]
        )
    case "east":
        return (
            [28, 2, 0], -7,
            [
                ["id": "east-rooftop-hvac", "kind": "rooftop-hvac", "positionWorld": [-9, 42.4, 10], "dimensions": [11, 7, 8], "materialID": "rooftop-metal"],
                ["id": "east-exhaust-stack", "kind": "exhaust-stack", "positionWorld": [-12, 44.1, -9], "dimensions": [4.5, 17, 4.5], "materialID": "exhaust-dark"],
                ["id": "east-service-tank", "kind": "service-tank", "positionWorld": [-18, 6.2, 21], "dimensions": [8, 12, 8], "materialID": "tank-oxide"],
            ],
            [[20, -24], [50, -24], [50, 24], [20, 24]]
        )
    case "south":
        return (
            [0, 2, 28], 6,
            [
                ["id": "south-rooftop-hvac", "kind": "rooftop-hvac", "positionWorld": [-10, 42.5, -8], "dimensions": [9, 7, 11], "materialID": "rooftop-metal"],
                ["id": "south-exhaust-stack", "kind": "exhaust-stack", "positionWorld": [13, 44.1, -9], "dimensions": [4.5, 17, 4.5], "materialID": "exhaust-dark"],
                ["id": "south-service-tank", "kind": "service-tank", "positionWorld": [-21, 6.2, -18], "dimensions": [8, 12, 8], "materialID": "tank-oxide"],
            ],
            [[24, 20], [-24, 20], [-24, 50], [24, 50]]
        )
    case "west":
        return (
            [-28, 2, 0], -10,
            [
                ["id": "west-rooftop-hvac", "kind": "rooftop-hvac", "positionWorld": [9, 42.3, -10], "dimensions": [11, 7, 8], "materialID": "rooftop-metal"],
                ["id": "west-exhaust-stack", "kind": "exhaust-stack", "positionWorld": [13, 44.1, 9], "dimensions": [4.5, 17, 4.5], "materialID": "exhaust-dark"],
                ["id": "west-service-tank", "kind": "service-tank", "positionWorld": [18, 6.2, -21], "dimensions": [8, 12, 8], "materialID": "tank-oxide"],
            ],
            [[-50, 24], [-50, -24], [-20, -24], [-20, 24]]
        )
    default:
        throw FreezeIndustrialError.invalid("invalid direction \(direction)")
    }
}

@main
enum FreezeIndustrialL1DescriptorsMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try industrialArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let manifestURL = URL(
            fileURLWithPath: try industrialArgument("--manifest", in: arguments)
        ).standardizedFileURL
        guard manifestURL.path.contains("/docs/production/evidence/PLAY-027/") else {
            throw FreezeIndustrialError.invalid(
                "manifest must remain under PLAY-027 evidence"
            )
        }
        let sceneRoot = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/scenes/industrial_l01/variant-0"
        )
        let materialsURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/materials/industrial-l01-l04-v0-materials.json"
        )
        let fingerprintURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/commercial-l01-l04/l04/diagnostics/schema2-sampling-regression-v03/TOOLCHAIN-FINGERPRINT.json"
        )
        let styleAnchorURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/GateA/golden_district_imagegen_source-v2.png"
        )
        let materialsData = try Data(contentsOf: materialsURL)
        let fingerprintData = try Data(contentsOf: fingerprintURL)
        let styleAnchorData = try Data(contentsOf: styleAnchorURL)
        let directions = ["north", "east", "south", "west"]
        let edges: [String: [[Double]]] = [
            "north": [[768, 640], [1024, 768]],
            "east": [[1024, 768], [768, 896]],
            "south": [[768, 896], [512, 768]],
            "west": [[512, 768], [768, 640]],
        ]
        let sockets: [String: [Double]] = [
            "north": [896, 704],
            "east": [896, 832],
            "south": [640, 832],
            "west": [640, 704],
        ]
        let doors: [String: [[Double]]] = [
            "north": [[858, 685], [934, 723]],
            "east": [[934, 813], [858, 851]],
            "south": [[678, 851], [602, 813]],
            "west": [[602, 723], [678, 685]],
        ]
        var samples: [[String: Any]] = []
        var descriptorHashes = Set<String>()
        var geometryIDs = Set<String>()

        for direction in directions {
            let directionData = try industrialDirectionData(direction)
            let geometryID =
                "industrial-l01-v0-\(direction)-loading-works-geometry-v1"
            let object: [String: Any] = [
                "schema": 2,
                "task": "PLAY-027",
                "sceneGeometryID": geometryID,
                "logicalBuildingID": "industrial_l01",
                "family": "industrial",
                "level": 1,
                "variantID": "variant-0",
                "viewDirection": direction,
                "sourceRevision": "source-v01",
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
                    "role": "frozen-schema-2-v3-offline-host-and-frameworks",
                    "file": industrialRelative(fingerprintURL, root: root),
                    "sha256": industrialSHA256(fingerprintData),
                ],
                "styleAnchor": [
                    "role": "immutable-appearance-only-global-style-anchor",
                    "file": industrialRelative(styleAnchorURL, root: root),
                    "sha256": industrialSHA256(styleAnchorData),
                ],
                "materialLibrary": [
                    "role": "shared-industrial-density-material-library",
                    "file": industrialRelative(materialsURL, root: root),
                    "sha256": industrialSHA256(materialsData),
                ],
                "registration": [
                    "tileBasisPoints": [72, 36],
                    "sceneFootprintUnits": [72, 72],
                    "footprintPolygonSource": [[768, 640], [1024, 768], [768, 896], [512, 768]],
                    "groundPivotSource": [768, 896],
                    "contactPolygonWorld": [[-28, -28], [28, -28], [28, 28], [-28, 28]],
                    "frontageEdgeSource": edges[direction]!,
                    "frontageSocketSource": sockets[direction]!,
                    "doorBaseSource": doors[direction]!,
                    "presentationEnvelopeSource": [256, 120, 1280, 896],
                    "shadowEnvelopeSource": [768, 512, 1456, 976],
                    "orientationTransform": "none",
                ],
                "camera": [
                    "projection": "orthographic-2:1",
                    "yawDegrees": 45,
                    "elevationDegrees": 30,
                    "orthographicScale": 203.64675298172568,
                    "renderViewportPixels": [1536, 1024],
                    "oversamplingFactor": 4,
                    "positionWorld": [180, 146.9693845669907, 180],
                    "targetWorld": [0, 0, 0],
                    "sourceGroundCenter": [768, 768],
                    "postProjectionOffsetPixels": [0, 256],
                ],
                "sampling": industrialSampling(),
                "light": [
                    "keyOrigin": [-120, 180, -120],
                    "keyIntensity": 1000,
                    "keyColorRGBA": [1.0, 0.86, 0.68, 1.0],
                    "ambientIntensity": 0.5,
                    "ambientColorRGBA": [0.50, 0.46, 0.38, 1.0],
                    "shadowVectorSource": [2, 1],
                    "shadowOpacity": 0.34,
                    "shadowBlurSourcePixels": 18,
                    "shadowReceiver": "task-owned-transparent-ground-plane",
                ],
                "building": [
                    "width": 56,
                    "depth": 56,
                    "foundationHeight": 2,
                    "floorHeight": 14,
                    "floors": 2,
                    "wallHeight": 28,
                    "roofHeight": 10,
                    "roofOverhang": 1,
                    "wallMaterialID": "corrugated-steel-sage",
                    "trimMaterialID": "concrete-industrial-warm",
                    "roofMaterialID": "roof-industrial-charcoal",
                    "foundationMaterialID": "concrete-industrial-warm",
                    "chimney": [
                        "positionWorld": [-20, 37.5, 14],
                        "dimensions": [4.5, 17, 4.5],
                        "materialID": "chimney-metal",
                    ],
                    "massingProfile": "low-high-bay-loading-works",
                    "usesLegacyDomesticDetails": false,
                    "massBlocks": [
                        ["id": "i01-main-assembly-hall", "dimensions": [52, 26, 48], "positionWorld": [0, 15, 2], "materialID": "corrugated-steel-sage"],
                        ["id": "i01-brick-service-wing", "dimensions": [18, 20, 16], "positionWorld": [17, 12.2, -16], "materialID": "brick-industrial-umber"],
                    ],
                    "roofVolumes": [
                        ["id": "i01-saw-bay-west", "shape": "hip", "dimensions": [17, 9, 48], "positionWorld": [-17.5, 32.8, 2], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
                        ["id": "i01-saw-bay-center", "shape": "hip", "dimensions": [17, 9, 48], "positionWorld": [0, 33.0, 2], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
                        ["id": "i01-saw-bay-east", "shape": "hip", "dimensions": [17, 9, 48], "positionWorld": [17.5, 33.2, 2], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
                    ],
                    "trimBands": [
                        ["id": "i01-concrete-datum", "dimensions": [53, 1.4, 49], "positionWorld": [0, 9.3, 2], "materialID": "concrete-industrial-warm"],
                        ["id": "i01-eave-safety-band", "dimensions": [52.5, 1.2, 48.5], "positionWorld": [0, 27.1, 2], "materialID": "hazard-yellow"],
                    ],
                ],
                "facades": try industrialFacades(direction),
                "entrance": [
                    "facadeID": "\(direction)-facade",
                    "baseWorld": directionData.entranceBase,
                    "width": 22,
                    "height": 18,
                    "depth": 2,
                    "doorMaterialID": "loading-door-steel",
                    "surroundMaterialID": "concrete-industrial-warm",
                    "stepCount": 1,
                    "stepRun": 2,
                    "canopyDepth": 18,
                    "hingeSide": direction == "east" || direction == "south" ? "left" : "right",
                    "pavilionWidth": 28,
                    "pavilionDepth": 7,
                    "pavilionHeight": 24,
                    "pavilionRoofHeight": 3,
                    "pavilionMaterialID": "hazard-yellow",
                    "porchWidth": 32,
                    "porchColumnWidth": 1.8,
                    "porchLateralOffset": directionData.lateralOffset,
                    "style": "loading-bay",
                ],
                "props": directionData.props,
                "occlusionExclusions": [
                    [
                        "id": "\(direction)-loading-frontage-clearance",
                        "purpose": "protect the declared industrial loading-bay socket, dock apron, and visible service-yard return",
                        "polygonWorld": directionData.exclusion,
                    ]
                ],
            ]
            var data = try JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            )
            data.append(0x0a)
            let sceneURL = sceneRoot
                .appendingPathComponent(direction)
                .appendingPathComponent("scene.json")
            try FileManager.default.createDirectory(
                at: sceneURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: sceneURL, options: .atomic)
            let descriptorHash = industrialSHA256(data)
            guard descriptorHashes.insert(descriptorHash).inserted else {
                throw FreezeIndustrialError.invalid(
                    "\(direction) aliases a sibling descriptor"
                )
            }
            guard geometryIDs.insert(geometryID).inserted else {
                throw FreezeIndustrialError.invalid(
                    "\(direction) aliases a sibling geometry ID"
                )
            }
            samples.append([
                "direction": direction,
                "descriptorFile": industrialRelative(sceneURL, root: root),
                "descriptorSHA256": descriptorHash,
                "sceneGeometryID": geometryID,
                "sourceRevision": "source-v01",
                "orientationTransform": "none",
                "productionSelected": false,
            ])
        }
        let manifest: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "logicalBuildingID": "industrial_l01",
            "family": "industrial",
            "level": 1,
            "variant": 0,
            "sourceRevision": "source-v01",
            "contractID": "play027-deterministic-4x-no-msaa-lanczos-v3",
            "samplingPurpose": "source-authority",
            "descriptorCount": samples.count,
            "uniqueDescriptorHashCount": descriptorHashes.count,
            "uniqueSceneGeometryIDCount": geometryIDs.count,
            "samples": samples,
            "productionSelected": false,
        ]
        var manifestData = try JSONSerialization.data(
            withJSONObject: manifest,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        manifestData.append(0x0a)
        try FileManager.default.createDirectory(
            at: manifestURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try manifestData.write(to: manifestURL, options: .atomic)
    }
}
