import CryptoKit
import Foundation

enum RasterProofFreezeError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: freeze-industrial-l2-east-raster-survival-proof --repository-root <path>"
        case let .invalid(message):
            return message
        }
    }
}

private let rejectedEastSHA256 =
    "cfc2e4b352306619f9c3029d5e69325dcd716d22a844bec3aff7e48734472211"
private let rejectedMaterialSHA256 =
    "27e4c199da63e9a3a4e8c0084caa8c4f375e7b16499dd7a7b507cdb384eeb8e1"
private let acceptedIndustrialL1EastSHA256 =
    "33f781cc7d3f1164309cb5577947ff21588c0a97cc3e3c8ebf371931a1cc2520"
private let rejectedAuditSHA256 =
    "82f1733350bc975314b65aa74d4bdadf83bcb4a3a011332b8a94e0dfe88a6691"
private let exactOrthographicScale = 158.39191898578665
private let sourcePixelsPerWorldAxis = 512.0 / (56.0 * sqrt(2.0))
private let native2xScale = 144.0 / 512.0
private let native2xPixelsPerWorldAxis =
    sourcePixelsPerWorldAxis * native2xScale

private func argument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw RasterProofFreezeError.arguments
    }
    return arguments[index + 1]
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func sha256(_ url: URL) throws -> String {
    sha256(try Data(contentsOf: url))
}

private func object(_ url: URL) throws -> [String: Any] {
    guard
        let decoded = try JSONSerialization.jsonObject(
            with: Data(contentsOf: url)
        ) as? [String: Any]
    else {
        throw RasterProofFreezeError.invalid("could not decode \(url.path)")
    }
    return decoded
}

private func writeJSON(
    _ value: Any,
    to url: URL
) throws {
    var data = try JSONSerialization.data(
        withJSONObject: value,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: url, options: .atomic)
}

private func relative(
    _ url: URL,
    root: URL
) -> String {
    let prefix = root.path + "/"
    return url.path.hasPrefix(prefix)
        ? String(url.path.dropFirst(prefix.count))
        : url.path
}

private func block(
    _ id: String,
    _ dimensions: [Double],
    _ position: [Double],
    _ material: String
) -> [String: Any] {
    [
        "id": id,
        "dimensions": dimensions,
        "positionWorld": position,
        "materialID": material,
    ]
}

private func prop(
    _ id: String,
    _ kind: String,
    _ dimensions: [Double],
    _ position: [Double],
    _ material: String
) -> [String: Any] {
    [
        "id": id,
        "kind": kind,
        "dimensions": dimensions,
        "positionWorld": position,
        "materialID": material,
    ]
}

private func material(
    _ id: String,
    _ color: [Double],
    _ pattern: String,
    _ scale: [Double],
    roughness: Double,
    metalness: Double
) -> [String: Any] {
    [
        "id": id,
        "baseColorRGBA": color,
        "roughness": roughness,
        "metalness": metalness,
        "pattern": pattern,
        "physicalScaleWorld": scale,
        "textureMapping": [
            "mode": "world-scale-box-face-repeat-v1",
            "wrapS": "repeat",
            "wrapT": "repeat",
            "minificationFilter": "linear",
            "magnificationFilter": "linear",
            "mipFilter": "linear",
        ],
    ]
}

private let massBlocks: [[String: Any]] = [
    block(
        "proof-process-tower",
        [14, 55, 16],
        [-17, 30.5, -16],
        "proof-galvanized-northwest"
    ),
    block(
        "proof-production-hall",
        [23.5, 37, 36],
        [2, 21.5, -6],
        "proof-painted-production-steel"
    ),
    block(
        "proof-fabrication-step",
        [32, 27, 13.5],
        [-8, 16.5, 19.25],
        "proof-concrete-side"
    ),
    block(
        "proof-administration-wing",
        [15.5, 23, 13.5],
        [16.25, 14.5, 19.25],
        "proof-concrete-northwest"
    ),
    block(
        "proof-logistics-rear-wall",
        [4.5, 29, 36],
        [16.5, 17.5, -6],
        "proof-painted-production-steel"
    ),
    block(
        "proof-logistics-header",
        [4.25, 10, 36],
        [20.875, 27, -6],
        "proof-galvanized-northwest"
    ),
    block(
        "proof-logistics-pier-north",
        [4.25, 20, 4],
        [20.875, 12, -22],
        "proof-concrete-side"
    ),
    block(
        "proof-logistics-pier-ab",
        [4.25, 20, 3],
        [20.875, 12, -10.5],
        "proof-concrete-side"
    ),
    block(
        "proof-logistics-pier-bc",
        [4.25, 20, 3],
        [20.875, 12, 0.5],
        "proof-concrete-side"
    ),
    block(
        "proof-logistics-pier-south",
        [4.25, 20, 2],
        [20.875, 12, 11],
        "proof-concrete-side"
    ),
    block(
        "proof-dock-throat-a",
        [1.5, 15, 8],
        [19.1, 10.5, -16],
        "proof-deep-recess"
    ),
    block(
        "proof-dock-throat-b",
        [1.5, 15, 8],
        [19.1, 10.5, -5],
        "proof-deep-recess"
    ),
    block(
        "proof-dock-throat-c",
        [1.5, 15, 8],
        [19.1, 10.5, 6],
        "proof-deep-recess"
    ),
    block(
        "proof-dock-door-a",
        [2, 13, 7],
        [19.95, 10, -16],
        "proof-loading-door"
    ),
    block(
        "proof-dock-door-b",
        [2, 13, 7],
        [19.95, 10, -5],
        "proof-loading-door"
    ),
    block(
        "proof-dock-door-c",
        [2, 13, 7],
        [19.95, 10, 6],
        "proof-loading-door"
    ),
    block(
        "proof-dock-header-a",
        [4.5, 3, 9],
        [21.75, 18.25, -16],
        "proof-structural-trim"
    ),
    block(
        "proof-dock-header-b",
        [4.5, 3, 9],
        [21.75, 18.25, -5],
        "proof-structural-trim"
    ),
    block(
        "proof-dock-header-c",
        [4.5, 3, 9],
        [21.75, 18.25, 6],
        "proof-structural-trim"
    ),
    block(
        "proof-dock-canopy-a",
        [8, 3, 9],
        [24, 21.5, -16],
        "proof-galvanized-service"
    ),
    block(
        "proof-dock-canopy-b",
        [8, 3, 9],
        [24, 21.5, -5],
        "proof-galvanized-service"
    ),
    block(
        "proof-dock-canopy-c",
        [8, 3, 9],
        [24, 21.5, 6],
        "proof-galvanized-service"
    ),
    block(
        "proof-loading-apron",
        [6, 2, 38],
        [25, 1, -5],
        "proof-neutral-apron"
    ),
    block(
        "proof-dock-sill-a",
        [5, 3, 8],
        [24.5, 2.5, -16],
        "proof-structural-trim"
    ),
    block(
        "proof-dock-sill-b",
        [5, 3, 8],
        [24.5, 2.5, -5],
        "proof-structural-trim"
    ),
    block(
        "proof-dock-sill-c",
        [5, 3, 8],
        [24.5, 2.5, 6],
        "proof-structural-trim"
    ),
    block(
        "proof-personnel-door-recess",
        [2, 10, 6],
        [24.5, 8, 19],
        "proof-deep-recess"
    ),
    block(
        "proof-personnel-door",
        [2, 8, 4],
        [25.6, 7, 19],
        "proof-warm-glazing"
    ),
    block(
        "proof-personnel-canopy",
        [5, 2.5, 9],
        [25.5, 13.5, 19],
        "proof-structural-trim"
    ),
    block(
        "proof-admin-glazing",
        [2, 8, 9],
        [24.5, 16, 18.5],
        "proof-industrial-glazing"
    ),
    block(
        "proof-production-roof",
        [25.5, 3, 38],
        [2, 41.5, -6],
        "proof-roof-membrane"
    ),
    block(
        "proof-process-roof",
        [16, 3, 18],
        [-17, 59.5, -16],
        "proof-roof-membrane"
    ),
    block(
        "proof-fabrication-roof",
        [34, 3, 15.5],
        [-8, 31.5, 19.25],
        "proof-roof-membrane"
    ),
    block(
        "proof-admin-roof",
        [17.5, 3, 15.5],
        [16.25, 27.5, 19.25],
        "proof-roof-membrane"
    ),
    block(
        "proof-logistics-roof",
        [10, 3, 38],
        [19, 33.5, -6],
        "proof-roof-membrane"
    ),
    block(
        "proof-roof-monitor",
        [14, 8, 9],
        [2, 47, -7],
        "proof-galvanized-northwest"
    ),
    block(
        "proof-roof-monitor-glazing",
        [15, 4, 3],
        [2, 47, -2],
        "proof-industrial-glazing"
    ),
    block(
        "proof-hvac-bank",
        [12, 6, 7],
        [7, 46, 7],
        "proof-galvanized-service"
    ),
    block(
        "proof-pipe-bridge",
        [18, 3, 3],
        [-7, 44, -16],
        "proof-oxide-process"
    ),
    block(
        "proof-dock-hazard-header",
        [4, 3, 35],
        [26, 24.5, -5],
        "proof-safety-yellow"
    ),
]

private let props: [[String: Any]] = [
    prop(
        "proof-primary-exhaust",
        "explicit-cylinder",
        [5, 16, 5],
        [-19, 68, -18],
        "proof-oxide-process"
    ),
    prop(
        "proof-secondary-exhaust",
        "explicit-cylinder",
        [4, 12, 4],
        [-12, 64, -15],
        "proof-galvanized-service"
    ),
    prop(
        "proof-process-tank",
        "explicit-cylinder",
        [9, 18, 9],
        [-20, 12, 20],
        "proof-oxide-process"
    ),
    prop(
        "proof-bollard-north",
        "explicit-cylinder",
        [3, 6, 3],
        [27, 4, -22],
        "proof-safety-yellow"
    ),
    prop(
        "proof-bollard-south",
        "explicit-cylinder",
        [3, 6, 3],
        [27, 4, 13],
        "proof-safety-yellow"
    ),
    prop(
        "proof-personnel-bollard",
        "explicit-cylinder",
        [3, 6, 3],
        [27, 4, 24],
        "proof-safety-yellow"
    ),
]

private let materials: [[String: Any]] = [
    material(
        "proof-deep-recess",
        [0.045, 0.055, 0.065, 1],
        "solid-depth-cavity",
        [8, 8],
        roughness: 0.96,
        metalness: 0
    ),
    material(
        "proof-roof-membrane",
        [0.17, 0.19, 0.22, 1],
        "rolled-membrane-seams",
        [12, 12],
        roughness: 0.94,
        metalness: 0
    ),
    material(
        "proof-painted-production-steel",
        [0.31, 0.40, 0.48, 1],
        "procedural-vertical-corrugation",
        [8, 8],
        roughness: 0.73,
        metalness: 0.28
    ),
    material(
        "proof-loading-door",
        [0.48, 0.42, 0.32, 1],
        "horizontal-section-joints",
        [8, 14],
        roughness: 0.76,
        metalness: 0.18
    ),
    material(
        "proof-concrete-side",
        [0.47, 0.48, 0.45, 1],
        "procedural-formed-concrete",
        [10, 10],
        roughness: 0.95,
        metalness: 0
    ),
    material(
        "proof-neutral-apron",
        [0.52, 0.53, 0.50, 1],
        "large-scored-slabs",
        [12, 12],
        roughness: 0.98,
        metalness: 0
    ),
    material(
        "proof-concrete-northwest",
        [0.62, 0.60, 0.52, 1],
        "procedural-formed-concrete",
        [10, 10],
        roughness: 0.92,
        metalness: 0
    ),
    material(
        "proof-industrial-glazing",
        [0.18, 0.48, 0.60, 1],
        "muted-mullion-grid",
        [8, 8],
        roughness: 0.38,
        metalness: 0.10
    ),
    material(
        "proof-galvanized-northwest",
        [0.66, 0.70, 0.70, 1],
        "procedural-vertical-corrugation",
        [8, 8],
        roughness: 0.67,
        metalness: 0.58
    ),
    material(
        "proof-galvanized-service",
        [0.72, 0.75, 0.72, 1],
        "fine-galvanized",
        [8, 8],
        roughness: 0.62,
        metalness: 0.62
    ),
    material(
        "proof-structural-trim",
        [0.77, 0.73, 0.62, 1],
        "painted-steel",
        [8, 8],
        roughness: 0.66,
        metalness: 0.45
    ),
    material(
        "proof-oxide-process",
        [0.55, 0.28, 0.16, 1],
        "restrained-oxide",
        [8, 8],
        roughness: 0.78,
        metalness: 0.48
    ),
    material(
        "proof-warm-glazing",
        [0.90, 0.66, 0.32, 1],
        "muted-warm-glazing",
        [8, 8],
        roughness: 0.35,
        metalness: 0.08
    ),
    material(
        "proof-safety-yellow",
        [0.96, 0.67, 0.10, 1],
        "solid-safety-paint",
        [8, 8],
        roughness: 0.68,
        metalness: 0.22
    ),
]

private let featureBudgets: [[String: Any]] = [
    [
        "role": "three loading-door widths",
        "minimumWorldUnits": 7.0,
        "minimumNative2xPixels": 10.1,
        "identityBearing": true,
    ],
    [
        "role": "loading-throat depth",
        "minimumWorldUnits": 4.0,
        "minimumNative2xPixels": 5.8,
        "identityBearing": true,
    ],
    [
        "role": "dock canopy depth",
        "minimumWorldUnits": 8.0,
        "minimumNative2xPixels": 11.5,
        "identityBearing": true,
    ],
    [
        "role": "dock pier rhythm",
        "minimumWorldUnits": 3.0,
        "minimumNative2xPixels": 4.3,
        "identityBearing": true,
    ],
    [
        "role": "personnel entrance width",
        "minimumWorldUnits": 4.0,
        "minimumNative2xPixels": 5.8,
        "identityBearing": true,
    ],
    [
        "role": "bollard diameter",
        "minimumWorldUnits": 3.0,
        "minimumNative2xPixels": 4.3,
        "identityBearing": true,
    ],
    [
        "role": "large material rhythm",
        "minimumWorldUnits": 8.0,
        "minimumNative2xPixels": 11.5,
        "identityBearing": true,
    ],
]

private func finiteComponentEnvelope(
    scene: [String: Any]
) throws -> [String: Any] {
    guard
        let building = scene["building"] as? [String: Any],
        let blocks = building["massBlocks"] as? [[String: Any]],
        let sceneProps = scene["props"] as? [[String: Any]],
        let foundationDimensions =
            building["foundationDimensions"] as? [Double],
        let foundationPosition =
            building["foundationPositionWorld"] as? [Double]
    else {
        throw RasterProofFreezeError.invalid("proof geometry is malformed")
    }
    var components = blocks + sceneProps
    components.append([
        "id": "proof-foundation",
        "dimensions": foundationDimensions,
        "positionWorld": foundationPosition,
    ])
    var minimum = [Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude]
    var maximum = [-Double.greatestFiniteMagnitude, -Double.greatestFiniteMagnitude, -Double.greatestFiniteMagnitude]
    for component in components {
        guard
            let dimensions = component["dimensions"] as? [Double],
            let position = component["positionWorld"] as? [Double],
            dimensions.count == 3,
            position.count == 3,
            dimensions.allSatisfy({ $0.isFinite && $0 > 0 }),
            position.allSatisfy(\.isFinite)
        else {
            throw RasterProofFreezeError.invalid(
                "proof component contains invalid dimensions or position"
            )
        }
        for axis in 0..<3 {
            minimum[axis] = min(minimum[axis], position[axis] - dimensions[axis] / 2)
            maximum[axis] = max(maximum[axis], position[axis] + dimensions[axis] / 2)
        }
    }
    let registered =
        minimum[0] <= -28
        && maximum[0] >= 28
        && minimum[2] <= -28
        && maximum[2] >= 28
        && minimum[1] <= 0
        && maximum[1] >= 56
    guard registered else {
        throw RasterProofFreezeError.invalid(
            "proof envelope does not retain the registered 56x56 contact and vertical hierarchy"
        )
    }
    return [
        "minimumWorld": minimum,
        "maximumWorld": maximum,
        "requiredContactHalfExtents": [28, 28],
        "passed": registered,
    ]
}

@main
enum FreezeIndustrialL2EastRasterSurvivalProofMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try argument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let rejectedSceneURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/source-authority/quality-reset-v02/scenes/industrial_l02/variant-0/east/scene.json"
        )
        let rejectedMaterialURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/materials/industrial-l02-quality-reset-source-v09-materials.json"
        )
        let l1SceneURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/scenes/industrial_l01/variant-0/east/scene.json"
        )
        let rejectedAuditURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/quality-reset-source-v10-raw-gate/QUALITY-ROOT-CAUSE-AUDIT.md"
        )
        guard
            try sha256(rejectedSceneURL) == rejectedEastSHA256,
            try sha256(rejectedMaterialURL) == rejectedMaterialSHA256,
            try sha256(l1SceneURL) == acceptedIndustrialL1EastSHA256,
            try sha256(rejectedAuditURL) == rejectedAuditSHA256
        else {
            throw RasterProofFreezeError.invalid(
                "immutable accepted/rejected authority hash drift"
            )
        }

        let proofRoot = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-raster-survival-v01"
        )
        let sceneURL = proofRoot.appendingPathComponent(
            "scenes/industrial_l02/variant-0/east/scene.json"
        )
        let materialURL = proofRoot.appendingPathComponent(
            "materials/industrial-l02-raster-survival-art-proof-v01.json"
        )
        let evidenceRoot = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/raster-survival-art-proof-v01/prepixel"
        )

        let rejected = try object(rejectedSceneURL)
        guard
            let immutableRegistration = rejected["registration"],
            let immutableLight = rejected["light"],
            let immutableDerivation = rejected["derivation"],
            let immutableToolchain = rejected["toolchainFingerprint"],
            let immutableStyleAnchor = rejected["styleAnchor"],
            var camera = rejected["camera"] as? [String: Any],
            var sampling = rejected["sampling"] as? [String: Any],
            var building = rejected["building"] as? [String: Any],
            var entrance = rejected["entrance"] as? [String: Any],
            var facades = rejected["facades"] as? [[String: Any]]
        else {
            throw RasterProofFreezeError.invalid(
                "rejected East descriptor lacks required frozen contracts"
            )
        }

        let materialLibrary: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "libraryID": "industrial-l02-raster-survival-art-proof-v01",
            "source":
                "offline-only numerical material/value redesign; no ImageGen building or new swatch",
            "styleAnchorFile":
                "Native/CitySimNative/WorldArt/GateA/golden_district_imagegen_source-v2.png",
            "styleAnchorSHA256":
                "b227286bfe5ffe8cfc920d3faf8abe081f5cca8a498c215bfb8a840a448e7425",
            "familyAnchorFile":
                "Native/CitySimNative/WorldArt/GeneratedV4/ImageGen/raw/calibration/industrial_l01/source-v01.png",
            "familyAnchorSHA256":
                "22dbf75f35d66f86b108c8e5ab9d7b3f753df74489d0b9e9877fc81ba86a2515",
            "imageGenMaterialSwatchesUsed": false,
            "colorSpace": "extended-sRGB",
            "materials": materials,
            "productionSelected": false,
        ]
        try writeJSON(materialLibrary, to: materialURL)
        let materialHash = try sha256(materialURL)

        camera["orthographicScale"] = exactOrthographicScale
        sampling["purpose"] = "diagnostic-regression"
        sampling["sourceRevisionBinding"] = "art-proof-v01"
        sampling["sceneKitAntialiasing"] = "none"
        sampling["sceneKitShadows"] = "current"
        sampling["sceneKitLightingMode"] = "lambert-scene-lights"
        sampling.removeValue(forKey: "preLanczosCanonicalizer")

        building["massingProfile"] =
            "industrial-l02-east-raster-survival-large-form-v01"
        building["massBlocks"] = massBlocks
        building["props"] = nil
        building["wallHeight"] = 53.0
        building["roofHeight"] = 3.0
        building["roofMaterialID"] = "proof-roof-membrane"
        building["wallMaterialID"] = "proof-painted-production-steel"
        building["trimMaterialID"] = "proof-structural-trim"
        building["foundationMaterialID"] = "proof-concrete-side"
        building["foundationDimensions"] = [55.0, 3.0, 56.0]
        building["foundationPositionWorld"] = [-0.5, 1.5, 0.0]
        building["chimney"] = [
            "dimensions": [1.0, 1.0, 1.0],
            "positionWorld": [0.0, 1.0, 0.0],
            "materialID": "proof-galvanized-service",
        ]

        for index in facades.indices {
            facades[index]["materialID"] =
                facades[index]["direction"] as? String == "east"
                ? "proof-painted-production-steel"
                : "proof-concrete-side"
            facades[index]["windowBays"] = []
            facades[index]["windowRhythms"] = []
        }
        entrance["doorMaterialID"] = "proof-loading-door"
        entrance["surroundMaterialID"] = "proof-structural-trim"
        entrance["pavilionMaterialID"] = "proof-painted-production-steel"

        let scene: [String: Any] = [
            "schema": 2,
            "task": "PLAY-027",
            "sceneGeometryID":
                "industrial-l02-east-raster-survival-art-proof-geometry-v01",
            "logicalBuildingID": "industrial_l02",
            "family": "industrial",
            "level": 2,
            "variantID": "variant-0",
            "viewDirection": "east",
            "sourceRevision": "art-proof-v01",
            "authoredIndependently": true,
            "productionSelected": false,
            "derivation": immutableDerivation,
            "toolchainFingerprint": immutableToolchain,
            "styleAnchor": immutableStyleAnchor,
            "materialLibrary": [
                "role":
                    "industrial-l02-east-raster-survival-offline-only-material-roles",
                "file": relative(materialURL, root: root),
                "sha256": materialHash,
            ],
            "registration": immutableRegistration,
            "camera": camera,
            "sampling": sampling,
            "light": immutableLight,
            "building": building,
            "facades": facades,
            "entrance": entrance,
            "props": props,
            "occlusionExclusions": [
                [
                    "id": "east-raster-survival-loading-clearance",
                    "purpose":
                        "protect three grounded dock throats, canopies, apron, and personnel entrance at the exact East socket",
                    "polygonWorld": [
                        [18.0, -28.0],
                        [28.0, -28.0],
                        [28.0, 28.0],
                        [18.0, 28.0],
                    ],
                ]
            ],
        ]
        try writeJSON(scene, to: sceneURL)

        let sceneHash = try sha256(sceneURL)
        let envelope = try finiteComponentEnvelope(scene: scene)
        let expectedDiamondWidth =
            1024.0 * (56.0 * sqrt(2.0)) / exactOrthographicScale
        let expectedDiamondHeight =
            1024.0 * (56.0 * sqrt(2.0) * 0.5)
            / exactOrthographicScale
        guard
            abs(expectedDiamondWidth - 512) < 0.000_001,
            abs(expectedDiamondHeight - 256) < 0.000_001,
            featureBudgets.allSatisfy({
                ($0["minimumNative2xPixels"] as? Double ?? 0) >= 4
            })
        else {
            throw RasterProofFreezeError.invalid(
                "projection or native-scale survival contract failed"
            )
        }

        let materialLumaTargets: [[String: Any]] = [
            ["role": "recess", "targetStep32Bin": 16, "minimumSeparationBins": 1],
            ["role": "roof", "targetStep32Bin": 48, "minimumSeparationBins": 1],
            ["role": "painted steel", "targetStep32Bin": 80, "minimumSeparationBins": 1],
            ["role": "loading door", "targetStep32Bin": 112, "minimumSeparationBins": 1],
            ["role": "concrete", "targetStep32Bin": 144, "minimumSeparationBins": 1],
            ["role": "galvanized/trim", "targetStep32Bin": 176, "minimumSeparationBins": 1],
            ["role": "glazing/safety highlight", "targetStep32Bin": 208, "minimumSeparationBins": 1],
        ]
        let neutralReviewContract: [String: Any] = [
            "authority": "review-presentation-only-never-source-or-normalization",
            "input": "exact emitted flat-chroma raw PNG",
            "classification":
                "8-connected border flood over exact chroma or chroma-shadow family where g<=8, abs(r-b)<=2, and r>=16",
            "exactChromaOutput": "rgba(0,0,0,0)",
            "shadowChromaOutput":
                "rgba(0,0,0,255-r), reconstructing black shadow alpha from black-over-magenta composite",
            "nonBackgroundOutput": "byte-exact opaque source pixel",
            "neutralCompositeRGBA": [224, 226, 220, 255],
            "failClosed":
                "reject if classified shadow family touches any non-background material region or changes occupied non-background bounds",
        ]
        let failCriteria = [
            "projected source-diamond utilization <= 0.801",
            "any of the three loading doors or canopies is not independently readable at native-2x",
            "administration, production, process, and loading forms merge in color or post-step32 grayscale",
            "identity depends on a feature narrower than 4 native-2x pixels",
            "opaque magenta or magenta-shadow plate remains in the alpha-respecting review treatment",
            "footprint, pivot, East socket, door base, contact shadow, camera direction, or 2:1 registration drifts",
            "visual result remains dark, flat, toy-like, or weaker than accepted Industrial L1",
        ]
        let validation: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type": "industrial-l02-east-raster-survival-prepixel-validation",
            "authority": "single-process-non-source-authority-art-proof",
            "sceneDescriptorFile": relative(sceneURL, root: root),
            "sceneDescriptorSHA256": sceneHash,
            "materialLibraryFile": relative(materialURL, root: root),
            "materialLibrarySHA256": materialHash,
            "immutableEvidence": [
                "rejectedSourceV10EastSHA256": rejectedEastSHA256,
                "rejectedSourceV10MaterialsSHA256": rejectedMaterialSHA256,
                "acceptedIndustrialL1EastSHA256":
                    acceptedIndustrialL1EastSHA256,
                "rejectedRootCauseAuditSHA256": rejectedAuditSHA256,
            ],
            "projection": [
                "yawDegrees": 45,
                "elevationDegrees": 30,
                "orthographicScale": exactOrthographicScale,
                "expectedSourceDiamondPixels": [512.0, 256.0],
                "expectedSourceDiamondUtilization": 1.0,
                "rejectedObservedSourceDiamondUtilization": 0.801,
                "sourcePixelsPerWorldAxis": sourcePixelsPerWorldAxis,
                "native2xPixelsPerWorldAxis": native2xPixelsPerWorldAxis,
                "registrationPreservation":
                    "56x56 world footprint analytically maps to frozen 512x256 diamond; East midpoint maps to frozen socket 896,832",
            ],
            "componentEnvelope": envelope,
            "featureBudgets": featureBudgets,
            "materialLumaTargets": materialLumaTargets,
            "neutralAlphaReview": neutralReviewContract,
            "failCriteria": failCriteria,
            "geometryIDUnique": true,
            "siblingTransform": "none",
            "productionSelected": false,
            "prepixelPassed": true,
        ]
        try writeJSON(
            validation,
            to: evidenceRoot.appendingPathComponent(
                "PREPIXEL-VALIDATION.json"
            )
        )

        let contract = """
        # PLAY-027 Industrial L2 East raster-survival presentation contract

        Status: frozen offline-only, single-process, non-source-authority proof. `productionSelected` is false.

        ## Immutable boundary

        - Rejected source-v10 East descriptor: `\(rejectedEastSHA256)`.
        - Rejected source-v10 material library: `\(rejectedMaterialSHA256)`.
        - Accepted Industrial L1 East descriptor: `\(acceptedIndustrialL1EastSHA256)`.
        - Rejected root-cause audit: `\(rejectedAuditSHA256)`.
        - No rejected or accepted source byte may change. No repeatability or canonicalization probe is part of this proof.

        ## Projection and envelope

        The camera direction remains yaw 45 degrees, elevation 30 degrees, orthographic 2:1, with the frozen target, source ground center, post-projection offset, pivot, East edge, socket, door base, and contact/shadow geometry. Orthographic scale is exactly `\(exactOrthographicScale)`. At that scale the 56 by 56 world footprint analytically projects to the frozen 512 by 256 source registration diamond: 100% diamond utilization versus the rejected observed 80.1%, without changing the 1536 by 1024 canvas.

        ## Large-form and native-scale survival

        Administration, production hall, process tower, fabrication step, and loading spine are separate large volumes. The East frontage is a physical four-world-unit throat with three seven-world-unit doors, three eight-world-unit canopies, three structural piers, grounded sills, a 38-world-unit apron, and a separate personnel entrance. At native-2x, every identity-bearing dimension is budgeted at four pixels or larger; the doors and canopies are approximately 10 and 12 pixels wide respectively. Subpixel panel seams are not identity-bearing.

        ## Post-step-32 value ladder

        The review must demonstrate broad visible roles after the frozen step-32 quantizer: recess 16, roof 48, painted steel 80, loading door 112, concrete 144, galvanized/trim 176, and glazing/safety highlight 208. Adjacent roles must remain at least one bin apart and the major-form grayscale span must cover at least four bins.

        ## Neutral alpha-respecting review

        The literal raw remains flat-chroma contract evidence. The accepted visual treatment is a review-only alpha extraction: flood from the canvas border through exact magenta and the mathematically identifiable black-over-magenta shadow family (`g <= 8`, `abs(r-b) <= 2`, `r >= 16`). Exact chroma becomes transparent. Shadow-family pixels become black with alpha `255-r`. Every other pixel remains byte-exact and opaque. Review sheets composite that result over neutral RGBA 224,226,220,255. This transform is forbidden as source authority, normalization, or an LOD.

        ## Binding stop

        One fresh Metal-visible East process only. Stop with a preserved visual rejection if utilization is not above 80.1%; the four large forms or three docks merge; any staff/dock cue needs zoom coaching; the neutral treatment retains an opaque magenta plate; registration drifts; post-step-32 roles collapse; or the result remains dark, flat, toy-like, or weaker than accepted Industrial L1. Passing local technical checks produces only an independent-review candidate, never self-acceptance.
        """
        let contractURL = evidenceRoot.appendingPathComponent(
            "PRESENTATION-CONTRACT.md"
        )
        try FileManager.default.createDirectory(
            at: contractURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try (contract + "\n").write(
            to: contractURL,
            atomically: true,
            encoding: .utf8
        )

        print("scene \(sceneHash)")
        print("materials \(materialHash)")
        print("projection 512x256 utilization=1.0")
        print("prepixel PASS productionSelected=false")
    }
}
