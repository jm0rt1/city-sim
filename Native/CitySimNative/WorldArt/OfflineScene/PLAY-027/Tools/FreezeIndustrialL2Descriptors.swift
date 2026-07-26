import CryptoKit
import Foundation

enum FreezeIndustrialL2Error: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: freeze-industrial-l2-descriptors --repository-root <path> --manifest <json>"
        case let .invalid(message):
            return message
        }
    }
}

struct IndustrialL2Architecture {
    let massBlocks: [[String: Any]]
    let roofVolumes: [[String: Any]]
    let trimBands: [[String: Any]]
    let chimney: [String: Any]
    let props: [[String: Any]]
    let entranceBase: [Double]
    let exclusion: [[Double]]
}

func industrialL2Argument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw FreezeIndustrialL2Error.arguments
    }
    return arguments[index + 1]
}

func industrialL2SHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

func industrialL2Relative(_ url: URL, root: URL) -> String {
    let prefix = root.path + "/"
    return url.path.hasPrefix(prefix)
        ? String(url.path.dropFirst(prefix.count))
        : url.path
}

func industrialL2Sampling() -> [String: Any] {
    [
        "contractID": "play027-deterministic-4x-no-msaa-lanczos-v3",
        "sourceRevisionBinding": "source-v03",
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

func industrialL2Facade(
    scenePrefix: String,
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
                "id": "\(scenePrefix)-\(direction)-high-clerestory",
                "centersWorld": centers,
                "width": 6.5,
                "height": 5.5,
                "sillHeight": 29,
                "floor": 2,
                "materialID": "industrial-glass",
            ]
        ],
    ]
}

func industrialL2Facades(_ direction: String) throws -> [[String: Any]] {
    switch direction {
    case "north":
        return [
            industrialL2Facade(
                scenePrefix: "i02-n",
                direction: "north",
                hasEntrance: true,
                centers: [
                    [-18, 34.5, -27.2],
                    [16, 34.5, -27.2],
                ]
            ),
            industrialL2Facade(
                scenePrefix: "i02-n",
                direction: "east",
                hasEntrance: false,
                centers: [
                    [27.2, 34.5, -14],
                    [27.2, 34.5, 2],
                    [27.2, 34.5, 18],
                ]
            ),
            industrialL2Facade(
                scenePrefix: "i02-n",
                direction: "south",
                hasEntrance: false,
                centers: [
                    [18, 34.5, 27.2],
                    [2, 34.5, 27.2],
                    [-16, 34.5, 27.2],
                ]
            ),
            industrialL2Facade(
                scenePrefix: "i02-n",
                direction: "west",
                hasEntrance: false,
                centers: [
                    [-27.2, 34.5, 15],
                    [-27.2, 34.5, -3],
                    [-27.2, 34.5, -19],
                ]
            ),
        ]
    case "east":
        return [
            industrialL2Facade(
                scenePrefix: "i02-e",
                direction: "north",
                hasEntrance: false,
                centers: [
                    [-17, 34.5, -27.2],
                    [0, 34.5, -27.2],
                    [18, 34.5, -27.2],
                ]
            ),
            industrialL2Facade(
                scenePrefix: "i02-e",
                direction: "east",
                hasEntrance: true,
                centers: [
                    [27.2, 34.5, -17],
                    [27.2, 34.5, 17],
                ]
            ),
            industrialL2Facade(
                scenePrefix: "i02-e",
                direction: "south",
                hasEntrance: false,
                centers: [
                    [18, 34.5, 27.2],
                    [1, 34.5, 27.2],
                    [-17, 34.5, 27.2],
                ]
            ),
            industrialL2Facade(
                scenePrefix: "i02-e",
                direction: "west",
                hasEntrance: false,
                centers: [
                    [-27.2, 34.5, 18],
                    [-27.2, 34.5, 1],
                    [-27.2, 34.5, -17],
                ]
            ),
        ]
    case "south":
        return [
            industrialL2Facade(
                scenePrefix: "i02-s",
                direction: "north",
                hasEntrance: false,
                centers: [
                    [-18, 34.5, -27.2],
                    [-1, 34.5, -27.2],
                    [17, 34.5, -27.2],
                ]
            ),
            industrialL2Facade(
                scenePrefix: "i02-s",
                direction: "east",
                hasEntrance: false,
                centers: [
                    [27.2, 34.5, -18],
                    [27.2, 34.5, 0],
                    [27.2, 34.5, 17],
                ]
            ),
            industrialL2Facade(
                scenePrefix: "i02-s",
                direction: "south",
                hasEntrance: true,
                centers: [
                    [17, 34.5, 27.2],
                    [-17, 34.5, 27.2],
                ]
            ),
            industrialL2Facade(
                scenePrefix: "i02-s",
                direction: "west",
                hasEntrance: false,
                centers: [
                    [-27.2, 34.5, 16],
                    [-27.2, 34.5, -2],
                    [-27.2, 34.5, -18],
                ]
            ),
        ]
    case "west":
        return [
            industrialL2Facade(
                scenePrefix: "i02-w",
                direction: "north",
                hasEntrance: false,
                centers: [
                    [-17, 34.5, -27.2],
                    [1, 34.5, -27.2],
                    [18, 34.5, -27.2],
                ]
            ),
            industrialL2Facade(
                scenePrefix: "i02-w",
                direction: "east",
                hasEntrance: false,
                centers: [
                    [27.2, 34.5, -17],
                    [27.2, 34.5, 0],
                    [27.2, 34.5, 18],
                ]
            ),
            industrialL2Facade(
                scenePrefix: "i02-w",
                direction: "south",
                hasEntrance: false,
                centers: [
                    [17, 34.5, 27.2],
                    [0, 34.5, 27.2],
                    [-18, 34.5, 27.2],
                ]
            ),
            industrialL2Facade(
                scenePrefix: "i02-w",
                direction: "west",
                hasEntrance: true,
                centers: [
                    [-27.2, 34.5, 17],
                    [-27.2, 34.5, -17],
                ]
            ),
        ]
    default:
        throw FreezeIndustrialL2Error.invalid(
            "invalid direction \(direction)"
        )
    }
}

func industrialL2Architecture(
    _ direction: String
) throws -> IndustrialL2Architecture {
    let prefix = "i02-\(direction)"
    switch direction {
    case "north":
        return IndustrialL2Architecture(
            massBlocks: [
                ["id": "\(prefix)-high-assembly-hall", "dimensions": [38, 42, 38], "positionWorld": [6, 23, 6], "materialID": "corrugated-steel-sage"],
                ["id": "\(prefix)-fabrication-annex", "dimensions": [18, 30, 48], "positionWorld": [-20.5, 17.2, 4], "materialID": "brick-industrial-umber"],
                ["id": "\(prefix)-process-tower", "dimensions": [14, 48, 16], "positionWorld": [18, 26.5, 15], "materialID": "brick-industrial-umber"],
                ["id": "\(prefix)-dual-dock-house", "dimensions": [48, 24, 12], "positionWorld": [0, 14.4, -22], "materialID": "brick-industrial-umber"],
                ["id": "\(prefix)-secondary-loading-door", "dimensions": [14, 18, 1.2], "positionWorld": [-18, 11.6, -28.4], "materialID": "loading-door-steel"],
                ["id": "\(prefix)-frontage-left-post", "dimensions": [3, 60, 3], "positionWorld": [-25, 32.25, -25], "materialID": "chimney-metal"],
                ["id": "\(prefix)-frontage-center-post", "dimensions": [3, 60, 3], "positionWorld": [-14, 32.25, -25], "materialID": "chimney-metal"],
                ["id": "\(prefix)-frontage-right-post", "dimensions": [3, 60, 3], "positionWorld": [25, 32.25, -25], "materialID": "chimney-metal"],
                ["id": "\(prefix)-service-apron", "dimensions": [50, 0.8, 20], "positionWorld": [0, 2.75, -23], "materialID": "concrete-industrial-warm"],
            ],
            roofVolumes: [
                ["id": "\(prefix)-sawtooth-west", "shape": "hip", "dimensions": [10, 10, 38], "positionWorld": [-6, 49.2, 6], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-sawtooth-center", "shape": "hip", "dimensions": [10, 10, 38], "positionWorld": [5, 49.4, 6], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-sawtooth-east", "shape": "hip", "dimensions": [10, 10, 38], "positionWorld": [16, 49.6, 6], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-annex-roof", "shape": "flat-parapet", "dimensions": [18, 5, 48], "positionWorld": [-20.5, 35, 4], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-tower-roof", "shape": "flat-parapet", "dimensions": [14, 5, 16], "positionWorld": [18, 53.2, 15], "materialID": "roof-industrial-charcoal", "trimMaterialID": "hazard-yellow"],
                ["id": "\(prefix)-dock-roof", "shape": "flat-parapet", "dimensions": [48, 5, 12], "positionWorld": [0, 29.1, -22], "materialID": "roof-industrial-charcoal", "trimMaterialID": "hazard-yellow"],
            ],
            trimBands: [
                ["id": "\(prefix)-hall-datum", "dimensions": [39, 1.6, 39], "positionWorld": [6, 11.1, 6], "materialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-annex-datum", "dimensions": [19, 1.4, 49], "positionWorld": [-20.5, 9.8, 4], "materialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-overhead-crane-rail", "dimensions": [40, 2.4, 3], "positionWorld": [5, 42.1, -10], "materialID": "hazard-yellow"],
                ["id": "\(prefix)-secondary-door-header", "dimensions": [18, 2.2, 2], "positionWorld": [-18, 21.9, -28.2], "materialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-frontage-secondary-header", "dimensions": [15, 4, 4], "positionWorld": [-19.5, 60, -25], "materialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-frontage-primary-header", "dimensions": [43, 4, 4], "positionWorld": [5.5, 60.1, -25], "materialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-frontage-secondary-crown", "dimensions": [13, 1.8, 4.6], "positionWorld": [-19.5, 63.4, -25], "materialID": "hazard-yellow"],
                ["id": "\(prefix)-frontage-primary-crown", "dimensions": [39, 1.8, 4.6], "positionWorld": [5.5, 63.6, -25], "materialID": "hazard-yellow"],
                ["id": "\(prefix)-apron-secondary-lane", "dimensions": [12, 0.3, 3], "positionWorld": [-18, 3.25, -30], "materialID": "hazard-yellow"],
                ["id": "\(prefix)-apron-primary-lane", "dimensions": [18, 0.3, 3], "positionWorld": [4, 3.35, -30], "materialID": "hazard-yellow"],
            ],
            chimney: ["positionWorld": [21, 53, 18], "dimensions": [5, 34, 5], "materialID": "chimney-metal"],
            props: [
                ["id": "\(prefix)-rooftop-hvac", "kind": "rooftop-hvac", "positionWorld": [-6, 59, 12], "dimensions": [12, 8, 10], "materialID": "rooftop-metal"],
                ["id": "\(prefix)-exhaust-stack", "kind": "exhaust-stack", "positionWorld": [8, 64, 4], "dimensions": [5, 24, 5], "materialID": "exhaust-dark"],
                ["id": "\(prefix)-service-tank", "kind": "service-tank", "positionWorld": [26, 9.55, -17], "dimensions": [9, 14, 9], "materialID": "tank-oxide"],
            ],
            entranceBase: [0, 2, -28],
            exclusion: [[-28, -52], [28, -52], [28, -18], [-28, -18]]
        )
    case "east":
        return IndustrialL2Architecture(
            massBlocks: [
                ["id": "\(prefix)-high-assembly-hall", "dimensions": [38, 42, 38], "positionWorld": [-6, 23, 6], "materialID": "corrugated-steel-sage"],
                ["id": "\(prefix)-fabrication-annex", "dimensions": [48, 30, 18], "positionWorld": [-4, 17.2, -20.5], "materialID": "brick-industrial-umber"],
                ["id": "\(prefix)-process-tower", "dimensions": [16, 48, 14], "positionWorld": [-15, 26.5, 18], "materialID": "brick-industrial-umber"],
                ["id": "\(prefix)-dual-dock-house", "dimensions": [12, 24, 48], "positionWorld": [22, 14.4, 0], "materialID": "brick-industrial-umber"],
                ["id": "\(prefix)-secondary-loading-door", "dimensions": [1.2, 18, 14], "positionWorld": [28.4, 11.6, -18], "materialID": "loading-door-steel"],
                ["id": "\(prefix)-frontage-left-post", "dimensions": [3, 60, 3], "positionWorld": [25, 32.25, -25], "materialID": "chimney-metal"],
                ["id": "\(prefix)-frontage-center-post", "dimensions": [3, 60, 3], "positionWorld": [25, 32.25, -14], "materialID": "chimney-metal"],
                ["id": "\(prefix)-frontage-right-post", "dimensions": [3, 60, 3], "positionWorld": [25, 32.25, 25], "materialID": "chimney-metal"],
                ["id": "\(prefix)-service-apron", "dimensions": [20, 0.8, 50], "positionWorld": [23, 2.75, 0], "materialID": "concrete-industrial-warm"],
            ],
            roofVolumes: [
                ["id": "\(prefix)-sawtooth-north", "shape": "hip", "dimensions": [38, 10, 10], "positionWorld": [-6, 49.2, -6], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-sawtooth-center", "shape": "hip", "dimensions": [38, 10, 10], "positionWorld": [-6, 49.4, 5], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-sawtooth-south", "shape": "hip", "dimensions": [38, 10, 10], "positionWorld": [-6, 49.6, 16], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-annex-roof", "shape": "flat-parapet", "dimensions": [48, 5, 18], "positionWorld": [-4, 35, -20.5], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-tower-roof", "shape": "flat-parapet", "dimensions": [16, 5, 14], "positionWorld": [-15, 53.2, 18], "materialID": "roof-industrial-charcoal", "trimMaterialID": "hazard-yellow"],
                ["id": "\(prefix)-dock-roof", "shape": "flat-parapet", "dimensions": [12, 5, 48], "positionWorld": [22, 29.1, 0], "materialID": "roof-industrial-charcoal", "trimMaterialID": "hazard-yellow"],
            ],
            trimBands: [
                ["id": "\(prefix)-hall-datum", "dimensions": [39, 1.6, 39], "positionWorld": [-6, 11.1, 6], "materialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-annex-datum", "dimensions": [49, 1.4, 19], "positionWorld": [-4, 9.8, -20.5], "materialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-overhead-crane-rail", "dimensions": [3, 2.4, 40], "positionWorld": [10, 42.1, 5], "materialID": "hazard-yellow"],
                ["id": "\(prefix)-secondary-door-header", "dimensions": [2, 2.2, 18], "positionWorld": [28.2, 21.9, -18], "materialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-frontage-secondary-header", "dimensions": [4, 4, 15], "positionWorld": [25, 60, -19.5], "materialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-frontage-primary-header", "dimensions": [4, 4, 43], "positionWorld": [25, 60.1, 5.5], "materialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-frontage-secondary-crown", "dimensions": [4.6, 1.8, 13], "positionWorld": [25, 63.4, -19.5], "materialID": "hazard-yellow"],
                ["id": "\(prefix)-frontage-primary-crown", "dimensions": [4.6, 1.8, 39], "positionWorld": [25, 63.6, 5.5], "materialID": "hazard-yellow"],
                ["id": "\(prefix)-apron-secondary-lane", "dimensions": [3, 0.3, 12], "positionWorld": [30, 3.25, -18], "materialID": "hazard-yellow"],
                ["id": "\(prefix)-apron-primary-lane", "dimensions": [3, 0.3, 18], "positionWorld": [30, 3.35, 4], "materialID": "hazard-yellow"],
            ],
            chimney: ["positionWorld": [-18, 53, 21], "dimensions": [5, 34, 5], "materialID": "chimney-metal"],
            props: [
                ["id": "\(prefix)-rooftop-hvac", "kind": "rooftop-hvac", "positionWorld": [-12, 59, -6], "dimensions": [10, 8, 12], "materialID": "rooftop-metal"],
                ["id": "\(prefix)-exhaust-stack", "kind": "exhaust-stack", "positionWorld": [-4, 64, 8], "dimensions": [5, 24, 5], "materialID": "exhaust-dark"],
                ["id": "\(prefix)-service-tank", "kind": "service-tank", "positionWorld": [17, 9.55, 26], "dimensions": [9, 14, 9], "materialID": "tank-oxide"],
            ],
            entranceBase: [28, 2, 0],
            exclusion: [[18, -28], [52, -28], [52, 28], [18, 28]]
        )
    case "south":
        return IndustrialL2Architecture(
            massBlocks: [
                ["id": "\(prefix)-high-assembly-hall", "dimensions": [38, 42, 38], "positionWorld": [-6, 23, -6], "materialID": "corrugated-steel-sage"],
                ["id": "\(prefix)-fabrication-annex", "dimensions": [18, 30, 48], "positionWorld": [20.5, 17.2, -4], "materialID": "brick-industrial-umber"],
                ["id": "\(prefix)-process-tower", "dimensions": [14, 48, 16], "positionWorld": [-18, 26.5, -15], "materialID": "brick-industrial-umber"],
                ["id": "\(prefix)-dual-dock-house", "dimensions": [48, 24, 12], "positionWorld": [0, 14.4, 22], "materialID": "brick-industrial-umber"],
                ["id": "\(prefix)-secondary-loading-door", "dimensions": [14, 18, 1.2], "positionWorld": [18, 11.6, 28.4], "materialID": "loading-door-steel"],
                ["id": "\(prefix)-frontage-left-post", "dimensions": [3, 60, 3], "positionWorld": [25, 32.25, 25], "materialID": "chimney-metal"],
                ["id": "\(prefix)-frontage-center-post", "dimensions": [3, 60, 3], "positionWorld": [14, 32.25, 25], "materialID": "chimney-metal"],
                ["id": "\(prefix)-frontage-right-post", "dimensions": [3, 60, 3], "positionWorld": [-25, 32.25, 25], "materialID": "chimney-metal"],
                ["id": "\(prefix)-service-apron", "dimensions": [50, 0.8, 20], "positionWorld": [0, 2.75, 23], "materialID": "concrete-industrial-warm"],
            ],
            roofVolumes: [
                ["id": "\(prefix)-sawtooth-east", "shape": "hip", "dimensions": [10, 10, 38], "positionWorld": [6, 49.2, -6], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-sawtooth-center", "shape": "hip", "dimensions": [10, 10, 38], "positionWorld": [-5, 49.4, -6], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-sawtooth-west", "shape": "hip", "dimensions": [10, 10, 38], "positionWorld": [-16, 49.6, -6], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-annex-roof", "shape": "flat-parapet", "dimensions": [18, 5, 48], "positionWorld": [20.5, 35, -4], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-tower-roof", "shape": "flat-parapet", "dimensions": [14, 5, 16], "positionWorld": [-18, 53.2, -15], "materialID": "roof-industrial-charcoal", "trimMaterialID": "hazard-yellow"],
                ["id": "\(prefix)-dock-roof", "shape": "flat-parapet", "dimensions": [48, 5, 12], "positionWorld": [0, 29.1, 22], "materialID": "roof-industrial-charcoal", "trimMaterialID": "hazard-yellow"],
            ],
            trimBands: [
                ["id": "\(prefix)-hall-datum", "dimensions": [39, 1.6, 39], "positionWorld": [-6, 11.1, -6], "materialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-annex-datum", "dimensions": [19, 1.4, 49], "positionWorld": [20.5, 9.8, -4], "materialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-overhead-crane-rail", "dimensions": [40, 2.4, 3], "positionWorld": [-5, 42.1, 10], "materialID": "hazard-yellow"],
                ["id": "\(prefix)-secondary-door-header", "dimensions": [18, 2.2, 2], "positionWorld": [18, 21.9, 28.2], "materialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-frontage-secondary-header", "dimensions": [15, 4, 4], "positionWorld": [19.5, 60, 25], "materialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-frontage-primary-header", "dimensions": [43, 4, 4], "positionWorld": [-5.5, 60.1, 25], "materialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-frontage-secondary-crown", "dimensions": [13, 1.8, 4.6], "positionWorld": [19.5, 63.4, 25], "materialID": "hazard-yellow"],
                ["id": "\(prefix)-frontage-primary-crown", "dimensions": [39, 1.8, 4.6], "positionWorld": [-5.5, 63.6, 25], "materialID": "hazard-yellow"],
                ["id": "\(prefix)-apron-secondary-lane", "dimensions": [12, 0.3, 3], "positionWorld": [18, 3.25, 30], "materialID": "hazard-yellow"],
                ["id": "\(prefix)-apron-primary-lane", "dimensions": [18, 0.3, 3], "positionWorld": [-4, 3.35, 30], "materialID": "hazard-yellow"],
            ],
            chimney: ["positionWorld": [-21, 53, -18], "dimensions": [5, 34, 5], "materialID": "chimney-metal"],
            props: [
                ["id": "\(prefix)-rooftop-hvac", "kind": "rooftop-hvac", "positionWorld": [6, 59, -12], "dimensions": [12, 8, 10], "materialID": "rooftop-metal"],
                ["id": "\(prefix)-exhaust-stack", "kind": "exhaust-stack", "positionWorld": [-8, 64, -4], "dimensions": [5, 24, 5], "materialID": "exhaust-dark"],
                ["id": "\(prefix)-service-tank", "kind": "service-tank", "positionWorld": [-26, 9.55, 17], "dimensions": [9, 14, 9], "materialID": "tank-oxide"],
            ],
            entranceBase: [0, 2, 28],
            exclusion: [[28, 18], [-28, 18], [-28, 52], [28, 52]]
        )
    case "west":
        return IndustrialL2Architecture(
            massBlocks: [
                ["id": "\(prefix)-high-assembly-hall", "dimensions": [38, 42, 38], "positionWorld": [6, 23, -6], "materialID": "corrugated-steel-sage"],
                ["id": "\(prefix)-fabrication-annex", "dimensions": [48, 30, 18], "positionWorld": [4, 17.2, 20.5], "materialID": "brick-industrial-umber"],
                ["id": "\(prefix)-process-tower", "dimensions": [16, 48, 14], "positionWorld": [15, 26.5, -18], "materialID": "brick-industrial-umber"],
                ["id": "\(prefix)-dual-dock-house", "dimensions": [12, 24, 48], "positionWorld": [-22, 14.4, 0], "materialID": "brick-industrial-umber"],
                ["id": "\(prefix)-secondary-loading-door", "dimensions": [1.2, 18, 14], "positionWorld": [-28.4, 11.6, 18], "materialID": "loading-door-steel"],
                ["id": "\(prefix)-frontage-left-post", "dimensions": [3, 60, 3], "positionWorld": [-25, 32.25, 25], "materialID": "chimney-metal"],
                ["id": "\(prefix)-frontage-center-post", "dimensions": [3, 60, 3], "positionWorld": [-25, 32.25, 14], "materialID": "chimney-metal"],
                ["id": "\(prefix)-frontage-right-post", "dimensions": [3, 60, 3], "positionWorld": [-25, 32.25, -25], "materialID": "chimney-metal"],
                ["id": "\(prefix)-service-apron", "dimensions": [20, 0.8, 50], "positionWorld": [-23, 2.75, 0], "materialID": "concrete-industrial-warm"],
            ],
            roofVolumes: [
                ["id": "\(prefix)-sawtooth-south", "shape": "hip", "dimensions": [38, 10, 10], "positionWorld": [6, 49.2, 6], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-sawtooth-center", "shape": "hip", "dimensions": [38, 10, 10], "positionWorld": [6, 49.4, -5], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-sawtooth-north", "shape": "hip", "dimensions": [38, 10, 10], "positionWorld": [6, 49.6, -16], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-annex-roof", "shape": "flat-parapet", "dimensions": [48, 5, 18], "positionWorld": [4, 35, 20.5], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-tower-roof", "shape": "flat-parapet", "dimensions": [16, 5, 14], "positionWorld": [15, 53.2, -18], "materialID": "roof-industrial-charcoal", "trimMaterialID": "hazard-yellow"],
                ["id": "\(prefix)-dock-roof", "shape": "flat-parapet", "dimensions": [12, 5, 48], "positionWorld": [-22, 29.1, 0], "materialID": "roof-industrial-charcoal", "trimMaterialID": "hazard-yellow"],
            ],
            trimBands: [
                ["id": "\(prefix)-hall-datum", "dimensions": [39, 1.6, 39], "positionWorld": [6, 11.1, -6], "materialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-annex-datum", "dimensions": [49, 1.4, 19], "positionWorld": [4, 9.8, 20.5], "materialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-overhead-crane-rail", "dimensions": [3, 2.4, 40], "positionWorld": [-10, 42.1, -5], "materialID": "hazard-yellow"],
                ["id": "\(prefix)-secondary-door-header", "dimensions": [2, 2.2, 18], "positionWorld": [-28.2, 21.9, 18], "materialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-frontage-secondary-header", "dimensions": [4, 4, 15], "positionWorld": [-25, 60, 19.5], "materialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-frontage-primary-header", "dimensions": [4, 4, 43], "positionWorld": [-25, 60.1, -5.5], "materialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-frontage-secondary-crown", "dimensions": [4.6, 1.8, 13], "positionWorld": [-25, 63.4, 19.5], "materialID": "hazard-yellow"],
                ["id": "\(prefix)-frontage-primary-crown", "dimensions": [4.6, 1.8, 39], "positionWorld": [-25, 63.6, -5.5], "materialID": "hazard-yellow"],
                ["id": "\(prefix)-apron-secondary-lane", "dimensions": [3, 0.3, 12], "positionWorld": [-30, 3.25, 18], "materialID": "hazard-yellow"],
                ["id": "\(prefix)-apron-primary-lane", "dimensions": [3, 0.3, 18], "positionWorld": [-30, 3.35, -4], "materialID": "hazard-yellow"],
            ],
            chimney: ["positionWorld": [18, 53, -21], "dimensions": [5, 34, 5], "materialID": "chimney-metal"],
            props: [
                ["id": "\(prefix)-rooftop-hvac", "kind": "rooftop-hvac", "positionWorld": [12, 59, 6], "dimensions": [10, 8, 12], "materialID": "rooftop-metal"],
                ["id": "\(prefix)-exhaust-stack", "kind": "exhaust-stack", "positionWorld": [4, 64, -8], "dimensions": [5, 24, 5], "materialID": "exhaust-dark"],
                ["id": "\(prefix)-service-tank", "kind": "service-tank", "positionWorld": [-17, 9.55, -26], "dimensions": [9, 14, 9], "materialID": "tank-oxide"],
            ],
            entranceBase: [-28, 2, 0],
            exclusion: [[-52, 28], [-52, -28], [-18, -28], [-18, 28]]
        )
    default:
        throw FreezeIndustrialL2Error.invalid(
            "invalid direction \(direction)"
        )
    }
}

@main
enum FreezeIndustrialL2DescriptorsMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try industrialL2Argument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let manifestURL = URL(
            fileURLWithPath: try industrialL2Argument(
                "--manifest",
                in: arguments
            )
        ).standardizedFileURL
        guard manifestURL.path.contains(
            "/docs/production/evidence/PLAY-027/"
        ) else {
            throw FreezeIndustrialL2Error.invalid(
                "manifest must remain under PLAY-027 evidence"
            )
        }

        let toolRoot = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027"
        )
        let sceneRoot = toolRoot.appendingPathComponent(
            "scenes/industrial_l02/variant-0"
        )
        let rawRoot = toolRoot.appendingPathComponent(
            "raw/industrial_l02/variant-0"
        )
        if FileManager.default.fileExists(atPath: rawRoot.path) {
            throw FreezeIndustrialL2Error.invalid(
                "Industrial L2 raw output already exists; do not mutate frozen descriptors"
            )
        }
        let materialsURL = toolRoot.appendingPathComponent(
            "materials/industrial-l01-l04-v0-materials.json"
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
        var records: [[String: Any]] = []
        var descriptorHashes = Set<String>()
        var geometryIDs = Set<String>()

        for direction in directions {
            let architecture = try industrialL2Architecture(direction)
            let sceneURL = sceneRoot
                .appendingPathComponent(direction)
                .appendingPathComponent("scene.json")
            let geometryID =
                "industrial-l02-v0-\(direction)-integrated-logistics-geometry-v3"
            let object: [String: Any] = [
                "schema": 2,
                "task": "PLAY-027",
                "sceneGeometryID": geometryID,
                "logicalBuildingID": "industrial_l02",
                "family": "industrial",
                "level": 2,
                "variantID": "variant-0",
                "viewDirection": direction,
                "sourceRevision": "source-v03",
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
                    "file": industrialL2Relative(
                        fingerprintURL,
                        root: root
                    ),
                    "sha256": industrialL2SHA256(fingerprintData),
                ],
                "styleAnchor": [
                    "role": "immutable-appearance-only-global-style-anchor",
                    "file": industrialL2Relative(
                        styleAnchorURL,
                        root: root
                    ),
                    "sha256": industrialL2SHA256(styleAnchorData),
                ],
                "materialLibrary": [
                    "role":
                        "industrial-family-material-anchor-no-imagegen-swatches",
                    "file": industrialL2Relative(
                        materialsURL,
                        root: root
                    ),
                    "sha256": industrialL2SHA256(materialsData),
                ],
                "registration": [
                    "tileBasisPoints": [72, 36],
                    "sceneFootprintUnits": [72, 72],
                    "footprintPolygonSource": [
                        [768, 640],
                        [1024, 768],
                        [768, 896],
                        [512, 768],
                    ],
                    "groundPivotSource": [768, 896],
                    "contactPolygonWorld": [
                        [-28, -28],
                        [28, -28],
                        [28, 28],
                        [-28, 28],
                    ],
                    "frontageEdgeSource": edges[direction]!,
                    "frontageSocketSource": sockets[direction]!,
                    "doorBaseSource": doors[direction]!,
                    "presentationEnvelopeSource": [256, 80, 1280, 896],
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
                    "positionWorld": [
                        180,
                        146.9693845669907,
                        180,
                    ],
                    "targetWorld": [0, 0, 0],
                    "sourceGroundCenter": [768, 768],
                    "postProjectionOffsetPixels": [0, 256],
                ],
                "sampling": industrialL2Sampling(),
                "light": [
                    "keyOrigin": [-120, 180, -120],
                    "keyIntensity": 1000,
                    "keyColorRGBA": [1, 0.86, 0.68, 1],
                    "ambientIntensity": 0.5,
                    "ambientColorRGBA": [0.5, 0.46, 0.38, 1],
                    "shadowVectorSource": [2, 1],
                    "shadowOpacity": 0.34,
                    "shadowBlurSourcePixels": 18,
                    "shadowReceiver":
                        "task-owned-transparent-ground-plane",
                ],
                "building": [
                    "width": 60,
                    "depth": 60,
                    "foundationHeight": 2,
                    "floorHeight": 14,
                    "floors": 3,
                    "wallHeight": 42,
                    "roofHeight": 10,
                    "roofOverhang": 1,
                    "wallMaterialID": "corrugated-steel-sage",
                    "trimMaterialID": "concrete-industrial-warm",
                    "roofMaterialID": "roof-industrial-charcoal",
                    "foundationMaterialID":
                        "concrete-industrial-warm",
                    "chimney": architecture.chimney,
                    "massingProfile":
                        "dual-bay-logistics-foundry-v1",
                    "massBlocks": architecture.massBlocks,
                    "roofVolumes": architecture.roofVolumes,
                    "trimBands": architecture.trimBands,
                    "usesLegacyDomesticDetails": false,
                ],
                "facades": try industrialL2Facades(direction),
                "entrance": [
                    "facadeID": "\(direction)-facade",
                    "baseWorld": architecture.entranceBase,
                    "width": 22,
                    "height": 20,
                    "depth": 2.4,
                    "doorMaterialID": "loading-door-steel",
                    "surroundMaterialID":
                        "concrete-industrial-warm",
                    "stepCount": 1,
                    "stepRun": 2.5,
                    "canopyDepth": 20,
                    "hingeSide":
                        direction == "north" || direction == "east"
                            ? "right" : "left",
                    "pavilionWidth": 30,
                    "pavilionDepth": 8,
                    "pavilionHeight": 27,
                    "pavilionRoofHeight": 3,
                    "pavilionMaterialID": "hazard-yellow",
                    "porchWidth": 48,
                    "porchColumnWidth": 2,
                    "porchLateralOffset": 0,
                    "style": "loading-bay",
                ],
                "props": architecture.props,
                "occlusionExclusions": [
                    [
                        "id": "\(direction)-dual-loading-clearance",
                        "purpose":
                            "preserve exact socket, service apron, and dual logistics frontage",
                        "polygonWorld": architecture.exclusion,
                    ]
                ],
            ]
            var data = try JSONSerialization.data(
                withJSONObject: object,
                options: [
                    .prettyPrinted,
                    .sortedKeys,
                    .withoutEscapingSlashes,
                ]
            )
            data.append(0x0a)
            try FileManager.default.createDirectory(
                at: sceneURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: sceneURL, options: .atomic)
            let descriptorHash = industrialL2SHA256(data)
            guard descriptorHashes.insert(descriptorHash).inserted else {
                throw FreezeIndustrialL2Error.invalid(
                    "\(direction) aliases a sibling descriptor"
                )
            }
            guard geometryIDs.insert(geometryID).inserted else {
                throw FreezeIndustrialL2Error.invalid(
                    "\(direction) aliases a sibling geometry ID"
                )
            }
            records.append([
                "direction": direction,
                "descriptorFile": industrialL2Relative(
                    sceneURL,
                    root: root
                ),
                "descriptorSHA256": descriptorHash,
                "sceneGeometryID": geometryID,
                "massBlockCount": architecture.massBlocks.count,
                "roofVolumeCount": architecture.roofVolumes.count,
                "trimBandCount": architecture.trimBands.count,
                "frontageSocketSource": sockets[direction]!,
                "entranceBaseWorld": architecture.entranceBase,
                "orientationTransform": "none",
                "productionSelected": false,
            ])
        }

        let manifest: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "logicalBuildingID": "industrial_l02",
            "sourceRevision": "source-v03",
            "architecture":
                "asymmetric high assembly hall, fabrication annex, process tower, dual loading house, three-post gantry, and expanded service apron",
            "contractID":
                "play027-deterministic-4x-no-msaa-lanczos-v3",
            "descriptorCount": records.count,
            "uniqueDescriptorHashCount": descriptorHashes.count,
            "uniqueSceneGeometryIDCount": geometryIDs.count,
            "directions": records,
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
