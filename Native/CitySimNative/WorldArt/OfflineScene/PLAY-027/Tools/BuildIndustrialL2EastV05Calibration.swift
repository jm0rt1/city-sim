import CryptoKit
import Foundation

enum IndustrialL2EastV05CalibrationError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: build-industrial-l2-east-v05-calibration --repository-root <path>"
        case let .invalid(message):
            return message
        }
    }
}

private let v05BaseDescriptorSHA256 =
    "fdb92d39acb8847178a95d1e0f6315332a93eda01df71388e54582fe1e6f12bf"
private let v05BaseMaterialsSHA256 =
    "31f500488b7d143e88015bf71b53db4d1a4b19076563dc3d774d61f00c8b83a3"
private let v05VisibilityRepairSHA256 =
    "5163d30c15819b00d718d795fd541c71b94026907f48dd43c9a6e32d1f0f6c9f"
private let v05FoundationHalfExtent = 28.0
private let v05OrthographicScale = 79.1959533691406
private let v05SourcePixelsPerWorld = 1024.0 / (2.0 * v05OrthographicScale)
private let v05Native2xScale = 144.0 / 512.0

private func v05Argument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL2EastV05CalibrationError.arguments
    }
    return arguments[index + 1]
}

private func v05SHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func v05SHA256(_ url: URL) throws -> String {
    v05SHA256(try Data(contentsOf: url))
}

private func v05LoadObject(_ url: URL) throws -> [String: Any] {
    guard
        let object = try JSONSerialization.jsonObject(
            with: Data(contentsOf: url)
        ) as? [String: Any]
    else {
        throw IndustrialL2EastV05CalibrationError.invalid(
            "could not decode \(url.path)"
        )
    }
    return object
}

private func v05WriteJSON(
    _ value: Any,
    to url: URL
) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw IndustrialL2EastV05CalibrationError.invalid(
            "output must be absent: \(url.path)"
        )
    }
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

private func v05WriteText(
    _ value: String,
    to url: URL
) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw IndustrialL2EastV05CalibrationError.invalid(
            "output must be absent: \(url.path)"
        )
    }
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try (value + "\n").write(
        to: url,
        atomically: true,
        encoding: .utf8
    )
}

private func v05Block(
    _ id: String,
    dimensions: [Double],
    position: [Double],
    material: String,
    role: String,
    identityBearing: Bool = true
) -> [String: Any] {
    [
        "id": id,
        "dimensions": dimensions,
        "positionWorld": position,
        "materialID": material,
        "presentationRole": role,
        "identityBearing": identityBearing,
    ]
}

private func v05Prop(
    _ id: String,
    kind: String,
    dimensions: [Double],
    position: [Double],
    material: String,
    role: String,
    identityBearing: Bool = true
) -> [String: Any] {
    [
        "id": id,
        "kind": kind,
        "dimensions": dimensions,
        "positionWorld": position,
        "materialID": material,
        "presentationRole": role,
        "identityBearing": identityBearing,
    ]
}

private func v05Material(
    _ id: String,
    role: String,
    color: [Double],
    target: Int,
    roughness: Double,
    metalness: Double,
    pattern: String
) -> [String: Any] {
    [
        "id": id,
        "valueRole": role,
        "baseColorRGBA": color + [1.0],
        "targetPostLightStep32Bin": target,
        "roughness": roughness,
        "metalness": metalness,
        "pattern": pattern,
        "physicalScaleWorld": [8.0, 8.0],
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

private let v05Materials: [[String: Any]] = [
    v05Material(
        "v05-recess",
        role: "dock-and-door-recess",
        color: [0.30, 0.36, 0.40],
        target: 80,
        roughness: 0.96,
        metalness: 0.0,
        pattern: "solid-depth-cavity"
    ),
    v05Material(
        "v05-dock-door",
        role: "sectional-loading-door",
        color: [0.52, 0.61, 0.68],
        target: 144,
        roughness: 0.76,
        metalness: 0.16,
        pattern: "broad-horizontal-section-joints"
    ),
    v05Material(
        "v05-hall-metal",
        role: "blue-gray-corrugated-production-hall",
        color: [0.60, 0.72, 0.80],
        target: 176,
        roughness: 0.76,
        metalness: 0.22,
        pattern: "large-scale-vertical-corrugation"
    ),
    v05Material(
        "v05-hall-plinth",
        role: "formed-concrete-production-plinth",
        color: [0.68, 0.68, 0.64],
        target: 176,
        roughness: 0.96,
        metalness: 0.0,
        pattern: "large-formed-concrete-bays"
    ),
    v05Material(
        "v05-admin-concrete",
        role: "pale-administration-and-quality-concrete",
        color: [0.86, 0.82, 0.71],
        target: 208,
        roughness: 0.92,
        metalness: 0.0,
        pattern: "deep-jointed-formed-concrete"
    ),
    v05Material(
        "v05-roof",
        role: "light-seamed-roof-membrane",
        color: [0.76, 0.79, 0.80],
        target: 208,
        roughness: 0.94,
        metalness: 0.0,
        pattern: "broad-rolled-membrane-seams"
    ),
    v05Material(
        "v05-apron",
        role: "neutral-scored-logistics-apron",
        color: [0.74, 0.74, 0.68],
        target: 192,
        roughness: 0.98,
        metalness: 0.0,
        pattern: "large-scored-service-slabs"
    ),
    v05Material(
        "v05-glazing",
        role: "cool-industrial-glazing",
        color: [0.30, 0.53, 0.66],
        target: 144,
        roughness: 0.38,
        metalness: 0.08,
        pattern: "large-mullion-rhythm"
    ),
    v05Material(
        "v05-warm-glazing",
        role: "staff-entrance-glazing",
        color: [0.88, 0.68, 0.34],
        target: 208,
        roughness: 0.36,
        metalness: 0.06,
        pattern: "warm-entry-glazing"
    ),
    v05Material(
        "v05-process-metal",
        role: "galvanized-process-plant",
        color: [0.64, 0.69, 0.72],
        target: 176,
        roughness: 0.66,
        metalness: 0.46,
        pattern: "large-galvanized-panels"
    ),
    v05Material(
        "v05-duct-metal",
        role: "bright-roof-ductwork",
        color: [0.76, 0.77, 0.74],
        target: 208,
        roughness: 0.62,
        metalness: 0.52,
        pattern: "galvanized-duct-seams"
    ),
    v05Material(
        "v05-dark-steel",
        role: "structural-shadow-steel",
        color: [0.39, 0.46, 0.50],
        target: 112,
        roughness: 0.70,
        metalness: 0.38,
        pattern: "painted-structural-steel"
    ),
    v05Material(
        "v05-light-trim",
        role: "high-value-canopy-and-facade-trim",
        color: [0.90, 0.88, 0.78],
        target: 224,
        roughness: 0.64,
        metalness: 0.34,
        pattern: "painted-steel"
    ),
    v05Material(
        "v05-safety",
        role: "restrained-ochre-safety-accent",
        color: [0.92, 0.65, 0.16],
        target: 208,
        roughness: 0.62,
        metalness: 0.26,
        pattern: "solid-safety-paint"
    ),
    v05Material(
        "v05-foundation",
        role: "grounded-structural-foundation",
        color: [0.62, 0.62, 0.58],
        target: 160,
        roughness: 0.98,
        metalness: 0.0,
        pattern: "coarse-formed-concrete"
    ),
]

private let v05MassBlocks: [[String: Any]] = [
    v05Block(
        "v05-production-plinth",
        dimensions: [42.0, 5.0, 48.0],
        position: [-6.0, 4.9, -2.0],
        material: "v05-hall-plinth",
        role: "continuous grounded production plinth"
    ),
    v05Block(
        "v05-production-hall",
        dimensions: [41.6, 18.0, 47.6],
        position: [-6.0, 16.3, -2.0],
        material: "v05-hall-metal",
        role: "broad low forty-eight-unit production hall"
    ),
    v05Block(
        "v05-east-loading-spine",
        dimensions: [8.5, 20.0, 42.0],
        position: [18.75, 12.5, -5.0],
        material: "v05-hall-plinth",
        role: "continuous East logistics frontage spine"
    ),
    v05Block(
        "v05-admin-quality-wing",
        dimensions: [14.0, 16.0, 18.0],
        position: [20.5, 10.6, 19.0],
        material: "v05-admin-concrete",
        role: "separate administration and quality wing"
    ),
    v05Block(
        "v05-admin-glazing-band",
        dimensions: [1.1, 6.5, 10.0],
        position: [27.55, 12.2, 18.0],
        material: "v05-glazing",
        role: "large administration glazing rhythm"
    ),
    v05Block(
        "v05-admin-sill",
        dimensions: [1.6, 2.0, 17.2],
        position: [27.2, 6.0, 19.0],
        material: "v05-dark-steel",
        role: "grounding administration sill",
        identityBearing: false
    ),
    v05Block(
        "v05-dock-recess-a",
        dimensions: [2.4, 14.0, 11.5],
        position: [25.8, 10.0, -19.0],
        material: "v05-recess",
        role: "deep grounded loading recess A"
    ),
    v05Block(
        "v05-dock-recess-b",
        dimensions: [2.4, 14.0, 11.5],
        position: [25.8, 10.0, -5.0],
        material: "v05-recess",
        role: "deep grounded loading recess B"
    ),
    v05Block(
        "v05-dock-recess-c",
        dimensions: [2.4, 14.0, 11.5],
        position: [25.8, 10.0, 9.0],
        material: "v05-recess",
        role: "deep grounded loading recess C"
    ),
    v05Block(
        "v05-dock-door-a",
        dimensions: [0.8, 11.0, 8.5],
        position: [27.3, 9.0, -19.0],
        material: "v05-dock-door",
        role: "individually readable dock door A"
    ),
    v05Block(
        "v05-dock-door-b",
        dimensions: [0.8, 11.0, 8.5],
        position: [27.3, 9.0, -5.0],
        material: "v05-dock-door",
        role: "individually readable dock door B"
    ),
    v05Block(
        "v05-dock-door-c",
        dimensions: [0.8, 11.0, 8.5],
        position: [27.3, 9.0, 9.0],
        material: "v05-dock-door",
        role: "individually readable dock door C"
    ),
    v05Block(
        "v05-dock-canopy-a",
        dimensions: [7.0, 3.0, 12.5],
        position: [24.5, 17.7, -19.0],
        material: "v05-light-trim",
        role: "deep high-contrast dock canopy A"
    ),
    v05Block(
        "v05-dock-canopy-b",
        dimensions: [7.0, 3.0, 12.5],
        position: [24.5, 17.7, -5.0],
        material: "v05-light-trim",
        role: "deep high-contrast dock canopy B"
    ),
    v05Block(
        "v05-dock-canopy-c",
        dimensions: [7.0, 3.0, 12.5],
        position: [24.5, 17.7, 9.0],
        material: "v05-light-trim",
        role: "deep high-contrast dock canopy C"
    ),
    v05Block(
        "v05-dock-hazard-fascia-a",
        dimensions: [7.2, 1.8, 12.8],
        position: [24.2, 19.8, -19.0],
        material: "v05-safety",
        role: "dock A safety hierarchy"
    ),
    v05Block(
        "v05-dock-hazard-fascia-b",
        dimensions: [7.2, 1.8, 12.8],
        position: [24.2, 19.8, -5.0],
        material: "v05-safety",
        role: "dock B safety hierarchy"
    ),
    v05Block(
        "v05-dock-hazard-fascia-c",
        dimensions: [7.2, 1.8, 12.8],
        position: [24.2, 19.8, 9.0],
        material: "v05-safety",
        role: "dock C safety hierarchy"
    ),
    v05Block(
        "v05-loading-apron",
        dimensions: [6.0, 2.2, 48.0],
        position: [25.0, 1.1, -1.0],
        material: "v05-apron",
        role: "wide grounded East service apron"
    ),
    v05Block(
        "v05-personnel-recess",
        dimensions: [2.0, 10.0, 7.0],
        position: [26.1, 8.0, 23.0],
        material: "v05-recess",
        role: "grounded staff entrance recess"
    ),
    v05Block(
        "v05-personnel-door",
        dimensions: [0.8, 8.5, 5.5],
        position: [27.4, 7.35, 23.0],
        material: "v05-warm-glazing",
        role: "staff-scale entrance"
    ),
    v05Block(
        "v05-personnel-canopy",
        dimensions: [5.5, 2.5, 8.0],
        position: [25.0, 13.6, 23.0],
        material: "v05-safety",
        role: "distinct staff entrance canopy"
    ),
    v05Block(
        "v05-roof-north",
        dimensions: [43.5, 2.4, 16.0],
        position: [-6.0, 26.4, -18.0],
        material: "v05-roof",
        role: "north production roof plane"
    ),
    v05Block(
        "v05-roof-center",
        dimensions: [43.5, 3.2, 16.0],
        position: [-6.0, 26.8, -1.5],
        material: "v05-roof",
        role: "raised center production roof plane"
    ),
    v05Block(
        "v05-roof-south",
        dimensions: [29.0, 2.4, 15.0],
        position: [-13.0, 26.4, 14.5],
        material: "v05-roof",
        role: "south production roof plane"
    ),
    v05Block(
        "v05-admin-roof",
        dimensions: [15.5, 2.4, 19.5],
        position: [20.5, 19.4, 19.0],
        material: "v05-roof",
        role: "separate administration roof"
    ),
    v05Block(
        "v05-clerestory",
        dimensions: [25.0, 6.0, 9.0],
        position: [-7.0, 32.65, -5.0],
        material: "v05-glazing",
        role: "large readable production clerestory"
    ),
    v05Block(
        "v05-clerestory-cap",
        dimensions: [26.5, 2.0, 10.5],
        position: [-7.0, 35.0, -5.0],
        material: "v05-light-trim",
        role: "high-value hall roof silhouette"
    ),
    v05Block(
        "v05-process-platform",
        dimensions: [18.0, 3.5, 11.0],
        position: [-17.0, 29.0, 17.0],
        material: "v05-dark-steel",
        role: "secondary process platform"
    ),
    v05Block(
        "v05-hvac-bank-a",
        dimensions: [7.0, 5.0, 7.0],
        position: [-12.0, 32.5, 17.0],
        material: "v05-process-metal",
        role: "large readable roof plant A"
    ),
    v05Block(
        "v05-hvac-bank-b",
        dimensions: [7.0, 5.0, 7.0],
        position: [-21.0, 32.5, 17.0],
        material: "v05-process-metal",
        role: "large readable roof plant B"
    ),
    v05Block(
        "v05-main-duct",
        dimensions: [4.0, 4.0, 30.0],
        position: [-9.8, 30.5, 4.0],
        material: "v05-duct-metal",
        role: "visible roof duct hierarchy"
    ),
]

private let v05Props: [[String: Any]] = [
    v05Prop(
        "v05-process-vessel",
        kind: "explicit-cylinder",
        dimensions: [9.0, 16.0, 9.0],
        position: [-20.0, 11.0, 23.0],
        material: "v05-process-metal",
        role: "secondary process vessel"
    ),
    v05Prop(
        "v05-stack-a",
        kind: "explicit-cylinder",
        dimensions: [4.0, 9.0, 4.0],
        position: [-17.0, 33.0, 18.0],
        material: "v05-duct-metal",
        role: "restrained roof stack A"
    ),
    v05Prop(
        "v05-stack-b",
        kind: "explicit-cylinder",
        dimensions: [4.0, 7.0, 4.0],
        position: [-8.0, 32.1, 10.0],
        material: "v05-duct-metal",
        role: "restrained roof stack B"
    ),
    v05Prop(
        "v05-bollard-a",
        kind: "explicit-cylinder",
        dimensions: [3.5, 5.0, 3.5],
        position: [27.0, 3.7, -25.5],
        material: "v05-safety",
        role: "dock A approach protection"
    ),
    v05Prop(
        "v05-bollard-b",
        kind: "explicit-cylinder",
        dimensions: [3.5, 5.0, 3.5],
        position: [27.0, 3.7, -12.0],
        material: "v05-safety",
        role: "dock B approach protection"
    ),
    v05Prop(
        "v05-bollard-c",
        kind: "explicit-cylinder",
        dimensions: [3.5, 5.0, 3.5],
        position: [27.0, 3.7, 2.0],
        material: "v05-safety",
        role: "dock C approach protection"
    ),
    v05Prop(
        "v05-bollard-staff",
        kind: "explicit-cylinder",
        dimensions: [3.5, 5.0, 3.5],
        position: [27.0, 3.7, 26.0],
        material: "v05-safety",
        role: "staff route protection"
    ),
]

private func v05CanonicalGeometry(_ descriptor: [String: Any]) throws -> Data {
    func stripMaterials(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            var result: [String: Any] = [:]
            for (key, child) in dictionary
            where !key.lowercased().contains("material") {
                result[key] = stripMaterials(child)
            }
            return result
        }
        if let array = value as? [Any] {
            return array.map(stripMaterials)
        }
        return value
    }
    let keys = [
        "building",
        "camera",
        "registration",
        "entrance",
        "facades",
        "props",
        "occlusionExclusions",
    ]
    var contract: [String: Any] = [:]
    for key in keys {
        guard let value = descriptor[key] else {
            throw IndustrialL2EastV05CalibrationError.invalid(
                "descriptor missing \(key)"
            )
        }
        contract[key] = stripMaterials(value)
    }
    return try JSONSerialization.data(
        withJSONObject: contract,
        options: [.sortedKeys, .withoutEscapingSlashes]
    )
}

@main
enum BuildIndustrialL2EastV05CalibrationMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath:
                try v05Argument("--repository-root", in: arguments)
        ).standardizedFileURL
        let baseRoot = repositoryRoot.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-projection-silhouette-reset-v04"
        )
        let baseDescriptorURL = baseRoot.appendingPathComponent(
            "scenes/industrial_l02/variant-0/east/scene.json"
        )
        let baseMaterialsURL = baseRoot.appendingPathComponent(
            "materials/industrial-l02-projection-silhouette-reset-v04.json"
        )
        let visibilityRepairURL = repositoryRoot.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/projection-silhouette-reset-v04/raw-visibility-validator-repair/VISIBILITY-REPAIR.json"
        )
        guard
            try v05SHA256(baseDescriptorURL) == v05BaseDescriptorSHA256,
            try v05SHA256(baseMaterialsURL) == v05BaseMaterialsSHA256,
            try v05SHA256(visibilityRepairURL) == v05VisibilityRepairSHA256
        else {
            throw IndustrialL2EastV05CalibrationError.invalid(
                "approved v04 base or visibility repair drift"
            )
        }

        let outputArtRoot = repositoryRoot.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-east-calibration-v05"
        )
        let outputEvidenceRoot = repositoryRoot.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/east-calibration-v05"
        )
        guard
            !FileManager.default.fileExists(atPath: outputArtRoot.path),
            !FileManager.default.fileExists(atPath: outputEvidenceRoot.path)
        else {
            throw IndustrialL2EastV05CalibrationError.invalid(
                "v05 calibration output already exists"
            )
        }

        let materialLibrary: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "libraryID": "industrial-l02-east-calibration-v05",
            "colorSpace": "extended-sRGB",
            "source":
                "task-owned numeric material hierarchy derived from v04; no ImageGen or raster swatch",
            "imageGenMaterialSwatchesUsed": false,
            "productionSelected": false,
            "materials": v05Materials,
            "valueContract": [
                "occupiedP25Minimum": 80,
                "occupiedIQRMinimum": 48,
                "occupiedP95Minimum": 192,
                "minimumOccupiedStep32Bins": 5,
                "maximumSingleMajorFacadeBinShare": 0.35,
                "identityBearingMinimumStep32Bin": 80,
                "forbidden": [
                    "global bleaching",
                    "single bright roof slab",
                    "dark box massing",
                    "subpixel identity greebles",
                ],
            ],
        ]
        let materialURL = outputArtRoot.appendingPathComponent(
            "materials/industrial-l02-east-calibration-v05.json"
        )
        try v05WriteJSON(materialLibrary, to: materialURL)
        let materialSHA256 = try v05SHA256(materialURL)

        var descriptor = try v05LoadObject(baseDescriptorURL)
        guard
            var building = descriptor["building"] as? [String: Any],
            var sampling = descriptor["sampling"] as? [String: Any],
            var entrance = descriptor["entrance"] as? [String: Any]
        else {
            throw IndustrialL2EastV05CalibrationError.invalid(
                "approved v04 descriptor fields malformed"
            )
        }
        building["foundationMaterialID"] = "v05-foundation"
        building["massBlocks"] = v05MassBlocks
        building["massingProfile"] =
            "industrial-l02-east-wide-low-capable-campus-v05"
        building["wallHeight"] = 33.0
        building["wallMaterialID"] = "v05-hall-metal"
        building["roofMaterialID"] = "v05-roof"
        building["trimMaterialID"] = "v05-light-trim"
        descriptor["building"] = building
        descriptor["props"] = v05Props
        descriptor["sourceRevision"] =
            "east-quality-calibration-art-proof-v05"
        descriptor["sceneGeometryID"] =
            "industrial-l02-east-wide-low-capable-campus-geometry-v05"
        descriptor["materialLibrary"] = [
            "file":
                "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-east-calibration-v05/materials/industrial-l02-east-calibration-v05.json",
            "sha256": materialSHA256,
            "role":
                "industrial-l02-east-readable-logistics-and-manufacturing-v05",
        ]
        sampling["sourceRevisionBinding"] =
            "east-quality-calibration-art-proof-v05"
        sampling["purpose"] = "diagnostic-calibration"
        sampling["sceneKitAntialiasing"] = "none"
        sampling["linearOversamplingFactor"] = 4
        sampling["downsample"] = [
            "filter": "CILanczosScaleTransform",
            "scale": 0.25,
            "aspectRatio": 1.0,
        ]
        sampling.removeValue(forKey: "finiteEquivalenceTable")
        sampling.removeValue(forKey: "preLanczosCanonicalizer")
        descriptor["sampling"] = sampling
        entrance["baseWorld"] = [28.0, 3.0, 23.0]
        entrance["width"] = 7.0
        entrance["height"] = 10.0
        entrance["doorMaterialID"] = "v05-warm-glazing"
        entrance["surroundMaterialID"] = "v05-safety"
        entrance["style"] = "staff-entrance-plus-three-dock-frontage"
        descriptor["entrance"] = entrance
        descriptor["prePixelCalibrationAuthority"] = [
            "approvedBaseCommit":
                "0e062b86388985845eab47c820c51ef4fa48298a",
            "scope": "Industrial L2 East only",
            "sourceAuthorityPixels": false,
            "oneFreshMetalProcessAfterIndependentPrepixelFreeze": true,
            "normalizerFreshProcessesAfterCapture": 2,
            "productionSelected": false,
        ]
        descriptor["productionSelected"] = false

        let descriptorURL = outputArtRoot.appendingPathComponent(
            "scenes/industrial_l02/variant-0/east/scene.json"
        )
        try v05WriteJSON(descriptor, to: descriptorURL)
        let descriptorSHA256 = try v05SHA256(descriptorURL)
        let geometrySHA256 = v05SHA256(
            try v05CanonicalGeometry(descriptor)
        )

        let minimumIdentityWorld =
            (v05MassBlocks + v05Props).compactMap { component -> Double? in
                guard
                    component["identityBearing"] as? Bool == true,
                    let dimensions = component["dimensions"] as? [Double],
                    let id = component["id"] as? String
                else {
                    return nil
                }
                if id.contains("door")
                    || id.contains("recess")
                    || id.contains("glazing")
                {
                    return min(dimensions[1], dimensions[2])
                }
                return min(dimensions[0], dimensions[2])
            }.min() ?? 0
        let minimumIdentityNativePixels =
            minimumIdentityWorld
            * v05SourcePixelsPerWorld
            * v05Native2xScale
        let productionHallProjectedWidth =
            48.0 * v05SourcePixelsPerWorld
        let campusProjectedWidth =
            56.0 * v05SourcePixelsPerWorld * sqrt(2.0)
        let campusNativeWidth =
            campusProjectedWidth * v05Native2xScale
        let componentIDs =
            (v05MassBlocks + v05Props).compactMap { $0["id"] as? String }
        let uniqueComponentIDs = Set(componentIDs).count == componentIDs.count
        let materialIDs = v05Materials.compactMap { $0["id"] as? String }
        let uniqueMaterialIDs = Set(materialIDs).count == materialIDs.count
        let dockCount = v05MassBlocks.filter {
            ($0["id"] as? String)?.hasPrefix("v05-dock-door-") == true
        }.count
        let canopyCount = v05MassBlocks.filter {
            ($0["id"] as? String)?.hasPrefix("v05-dock-canopy-") == true
        }.count
        let passed =
            uniqueComponentIDs
            && uniqueMaterialIDs
            && dockCount == 3
            && canopyCount == 3
            && minimumIdentityNativePixels >= 6.0
            && descriptor["productionSelected"] as? Bool == false

        let contract: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type": "industrial-l02-east-v05-prepixel-calibration-contract",
            "scope": "East only",
            "disposition": "PREPIXEL_REVIEW_CANDIDATE",
            "sourceAuthorityPixels": false,
            "productionSelected": false,
            "preservedV04": [
                "descriptorSHA256": v05BaseDescriptorSHA256,
                "materialLibrarySHA256": v05BaseMaterialsSHA256,
                "visibilityRepairSHA256": v05VisibilityRepairSHA256,
            ],
            "frozenIdentity": [
                "descriptorSHA256": descriptorSHA256,
                "materialLibrarySHA256": materialSHA256,
                "canonicalGeometrySHA256": geometrySHA256,
                "sceneGeometryID":
                    "industrial-l02-east-wide-low-capable-campus-geometry-v05",
                "orientationTransform": "none",
                "siblingSource": false,
            ],
            "registration": [
                "footprintWorld": [
                    [-v05FoundationHalfExtent, -v05FoundationHalfExtent],
                    [v05FoundationHalfExtent, -v05FoundationHalfExtent],
                    [v05FoundationHalfExtent, v05FoundationHalfExtent],
                    [-v05FoundationHalfExtent, v05FoundationHalfExtent],
                ],
                "groundPivotSource": [768, 896],
                "frontageSocketSource": [896, 832],
                "frontageEdgeSource": [[1024, 768], [768, 896]],
                "doorBaseSource": [[934, 813], [858, 851]],
                "shadowVectorSource": [2, 1],
                "cameraProjection": "orthographic-2:1",
                "orthographicScale": v05OrthographicScale,
            ],
            "largeFormHierarchy": [
                "productionHallWorld": [42, 18, 48],
                "administrationQualityWingWorld": [14, 16, 18],
                "loadingSpineWorld": [8.5, 20, 42],
                "dockDoorWorldEach": [0.8, 11, 8.5],
                "dockCanopyWorldEach": [7, 3, 12.5],
                "clerestoryWorld": [25, 6, 9],
                "processPlantReadable": true,
                "roofDuctReadable": true,
                "stackHierarchySecondary": true,
            ],
            "actualScaleBudget": [
                "sourcePixelsPerWorld": v05SourcePixelsPerWorld,
                "native2xScale": v05Native2xScale,
                "minimumIdentityWorld": minimumIdentityWorld,
                "minimumIdentityNativePixels":
                    minimumIdentityNativePixels,
                "productionHallProjectedSourceWidth":
                    productionHallProjectedWidth,
                "fullCampusProjectedSourceWidth":
                    campusProjectedWidth,
                "fullCampusProjectedNative2xWidth":
                    campusNativeWidth,
                "minimumIdentityPixels": 6,
            ],
            "visualFailCriteria": [
                "dark or flat box massing",
                "three dock bays not separately readable at native-2x",
                "administration wing merges into production hall",
                "process plant and duct hierarchy disappear",
                "staff entrance or bollards require zoom coaching",
                "review is dominated by opaque magenta",
                "Industrial L2 aliases accepted Industrial L1",
            ],
            "laterRawGate": [
                "freshEastMetalProcesses": 1,
                "freshNoMetalNormalizerProcesses": 2,
                "otherDirectionsAuthorized": 0,
                "sampler":
                    "play027-diagnostics-4x-no-msaa-software-lanczos-v1",
                "normalizationOnlyAfterRawTechnicalAndVisualReview": true,
            ],
        ]
        let contractURL = outputEvidenceRoot.appendingPathComponent(
            "prepixel/PREPIXEL-CALIBRATION-CONTRACT.json"
        )
        try v05WriteJSON(contract, to: contractURL)
        let contractSHA256 = try v05SHA256(contractURL)

        let validation: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type": "industrial-l02-east-v05-prepixel-validation",
            "passed": passed,
            "descriptorSHA256": descriptorSHA256,
            "materialLibrarySHA256": materialSHA256,
            "canonicalGeometrySHA256": geometrySHA256,
            "contractSHA256": contractSHA256,
            "componentCount": componentIDs.count,
            "uniqueComponentIDs": uniqueComponentIDs,
            "materialCount": materialIDs.count,
            "uniqueMaterialIDs": uniqueMaterialIDs,
            "dockDoorCount": dockCount,
            "dockCanopyCount": canopyCount,
            "minimumIdentityNative2xPixels":
                minimumIdentityNativePixels,
            "orientationTransform": "none",
            "sourceDirection": "east",
            "siblingTransformCount": 0,
            "sourceAuthorityRawPixelCount": 0,
            "normalizedPixelCount": 0,
            "productionSelected": false,
        ]
        let validationURL = outputEvidenceRoot.appendingPathComponent(
            "prepixel/PREPIXEL-VALIDATION.json"
        )
        try v05WriteJSON(validation, to: validationURL)

        let review = """
        # PLAY-027 Industrial L2 East v05 pre-pixel review request

        Disposition: `PENDING_INDEPENDENT_PREPIXEL_REVIEW`.

        This East-only calibration retains the accepted projection, 56×56 footprint, pivot, East socket, door bases, northwest light, southeast authored contact shadow, and schema-2 v3 diagnostic sampler. It introduces a broader layered production hall, a separate administration/quality wing, three large recessed dock bays with individual canopies and safety fascia, a grounded staff entrance, and a readable roof/process/duct/stack hierarchy.

        The descriptor and material library are frozen by the committed hashes in `PREPIXEL-VALIDATION.json`. No source-authority raw, normalized LOD, other direction, production selection, shipping surface, shared renderer, or shared normalizer is included.

        Review the bound non-authority pre-pixel actual-scale color and grayscale comparison panels before authorizing the single East process. Reject before pixels if the new campus does not clearly advance beyond accepted Industrial L1 or if any identity cue depends on subpixel detail.
        """
        try v05WriteText(
            review,
            to: outputEvidenceRoot.appendingPathComponent(
                "prepixel/PREPIXEL-REVIEW-REQUEST.md"
            )
        )
        guard passed else {
            throw IndustrialL2EastV05CalibrationError.invalid(
                "prepixel validation failed"
            )
        }
        print(
            "PASS descriptor=\(descriptorSHA256) materials=\(materialSHA256) geometry=\(geometrySHA256) minimumNative2x=\(minimumIdentityNativePixels)"
        )
    }
}
