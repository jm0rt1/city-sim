import AppKit
import CryptoKit
import Foundation

enum IndustrialL3CohesionBuildError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return """
            usage: build-industrial-l3-cohesion-east \
              --repository-root <path> --output-root <path> \
              --regular-staged-frame <png> --compact-staged-frame <png>
            """
        case let .invalid(message):
            return message
        }
    }
}

private let baseDescriptorRelative =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
    + "art-proof/industrial-l03-directional-family-v02/scenes/"
    + "industrial_l03/variant-0/east/scene.json"
private let baseDescriptorSHA256 =
    "dbe0dd260d28d848864d4194826f5147ec91314cf75b95bff9349bbfe466342c"
private let baseMaterialsRelative =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
    + "art-proof/industrial-l03-directional-family-v02/materials/"
    + "industrial-l03-v02.json"
private let baseMaterialsSHA256 =
    "3a9b0d97e74c3aba1772fa0dac66151955db98b34d25212eee7e15472ce2715e"
private let baseRawRelative =
    "docs/production/evidence/PLAY-027/industrial-l03/l03/"
    + "source-completion-v02/diagnostics/raw-repeat/east/run-a/raw.png"
private let baseRawSHA256 =
    "5dd2999ad2916a8ccddcf91954e54d1dfcf1139f78977d05d738c3dbfff4b9af"
private let outputDescriptorRelative =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
    + "art-proof/industrial-l03-cohesion-east-v01/scenes/"
    + "industrial_l03/variant-0/east/scene.json"
private let outputMaterialsRelative =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
    + "art-proof/industrial-l03-cohesion-east-v01/materials/"
    + "industrial-l03-cohesion-east-v01.json"
private let evidenceRelative =
    "docs/production/evidence/PLAY-027/industrial-l03/l03/"
    + "cohesion-a0-east-v01/prepixel"

private struct MaterialTreatment {
    let newID: String
    let baseColor: [Double]
    let pattern: String
    let physicalScale: [Double]
    let roughness: Double
    let metalness: Double
    let role: String
}

private let materialTreatments: [String: MaterialTreatment] = [
    "l3-recess": MaterialTreatment(
        newID: "l3c-deep-recess",
        baseColor: [0.07, 0.09, 0.10, 1],
        pattern: "solid-depth-cavity",
        physicalScale: [12, 12],
        roughness: 0.96,
        metalness: 0.02,
        role: "deep dock and service cavity"
    ),
    "l3-dock-door": MaterialTreatment(
        newID: "l3c-heavy-dock-door",
        baseColor: [0.18, 0.23, 0.24, 1],
        pattern: "horizontal-section-joints",
        physicalScale: [10, 10],
        roughness: 0.84,
        metalness: 0.20,
        role: "heavy sectional loading door"
    ),
    "l3-hall-blue": MaterialTreatment(
        newID: "l3c-weathered-blue-steel",
        baseColor: [0.31, 0.43, 0.46, 1],
        pattern: "procedural-vertical-corrugation",
        physicalScale: [12, 10],
        roughness: 0.82,
        metalness: 0.24,
        role: "weathered production-hall steel"
    ),
    "l3-hall-light": MaterialTreatment(
        newID: "l3c-weathered-blue-steel-light",
        baseColor: [0.43, 0.53, 0.53, 1],
        pattern: "procedural-vertical-corrugation",
        physicalScale: [12, 10],
        roughness: 0.84,
        metalness: 0.18,
        role: "northwest-lit production steel"
    ),
    "l3-plinth": MaterialTreatment(
        newID: "l3c-warm-rusticated-plinth",
        baseColor: [0.40, 0.34, 0.27, 1],
        pattern: "rusticated-block",
        physicalScale: [14, 12],
        roughness: 0.97,
        metalness: 0,
        role: "grounded warm concrete plinth"
    ),
    "l3-admin-concrete": MaterialTreatment(
        newID: "l3c-warm-formed-concrete",
        baseColor: [0.64, 0.56, 0.43, 1],
        pattern: "procedural-formed-concrete",
        physicalScale: [12, 12],
        roughness: 0.94,
        metalness: 0,
        role: "warm control and administration concrete"
    ),
    "l3-foundation": MaterialTreatment(
        newID: "l3c-charcoal-foundation",
        baseColor: [0.21, 0.22, 0.20, 1],
        pattern: "large-scored-slabs",
        physicalScale: [14, 14],
        roughness: 0.98,
        metalness: 0,
        role: "dark ground-contact foundation"
    ),
    "l3-apron": MaterialTreatment(
        newID: "l3c-warm-scored-apron",
        baseColor: [0.50, 0.47, 0.40, 1],
        pattern: "large-scored-slabs",
        physicalScale: [16, 16],
        roughness: 0.98,
        metalness: 0,
        role: "warm neutral loading apron"
    ),
    "l3-roof": MaterialTreatment(
        newID: "l3c-weathered-roof-membrane",
        baseColor: [0.50, 0.49, 0.42, 1],
        pattern: "rolled-membrane-seams",
        physicalScale: [12, 12],
        roughness: 0.95,
        metalness: 0.03,
        role: "weathered low-glare roof membrane"
    ),
    "l3-roof-dark": MaterialTreatment(
        newID: "l3c-heavy-roof-outline",
        baseColor: [0.12, 0.16, 0.17, 1],
        pattern: "painted-steel",
        physicalScale: [12, 12],
        roughness: 0.82,
        metalness: 0.30,
        role: "heavy roof and parapet edge"
    ),
    "l3-glazing": MaterialTreatment(
        newID: "l3c-smoky-industrial-glazing",
        baseColor: [0.12, 0.24, 0.27, 1],
        pattern: "muted-mullion-grid",
        physicalScale: [12, 12],
        roughness: 0.48,
        metalness: 0.06,
        role: "smoky industrial glazing"
    ),
    "l3-warm-glazing": MaterialTreatment(
        newID: "l3c-warm-control-glazing",
        baseColor: [0.72, 0.47, 0.19, 1],
        pattern: "muted-warm-glazing",
        physicalScale: [12, 12],
        roughness: 0.44,
        metalness: 0.04,
        role: "warm occupied control entrance"
    ),
    "l3-process-metal": MaterialTreatment(
        newID: "l3c-oxidized-process-metal",
        baseColor: [0.49, 0.35, 0.24, 1],
        pattern: "restrained-oxide",
        physicalScale: [12, 12],
        roughness: 0.82,
        metalness: 0.42,
        role: "oxidized process tower metal"
    ),
    "l3-duct-metal": MaterialTreatment(
        newID: "l3c-dull-duct-metal",
        baseColor: [0.52, 0.51, 0.44, 1],
        pattern: "fine-galvanized",
        physicalScale: [12, 12],
        roughness: 0.72,
        metalness: 0.48,
        role: "dull galvanized ductwork"
    ),
    "l3-dark-steel": MaterialTreatment(
        newID: "l3c-charcoal-outline-steel",
        baseColor: [0.09, 0.12, 0.13, 1],
        pattern: "painted-steel",
        physicalScale: [12, 12],
        roughness: 0.82,
        metalness: 0.40,
        role: "structural outline and frame steel"
    ),
    "l3-light-trim": MaterialTreatment(
        newID: "l3c-warm-trim",
        baseColor: [0.74, 0.66, 0.50, 1],
        pattern: "painted-steel",
        physicalScale: [12, 12],
        roughness: 0.74,
        metalness: 0.26,
        role: "warm readable dock and entrance trim"
    ),
    "l3-safety": MaterialTreatment(
        newID: "l3c-restrained-safety",
        baseColor: [0.74, 0.38, 0.08, 1],
        pattern: "solid-safety-paint",
        physicalScale: [12, 12],
        roughness: 0.70,
        metalness: 0.18,
        role: "restrained safety accent"
    ),
    "l3-tank-oxide": MaterialTreatment(
        newID: "l3c-oxidized-tank",
        baseColor: [0.48, 0.27, 0.16, 1],
        pattern: "restrained-oxide",
        physicalScale: [12, 12],
        roughness: 0.84,
        metalness: 0.38,
        role: "oxidized tank and process vessel"
    ),
    "l3-pipe": MaterialTreatment(
        newID: "l3c-dull-pipe",
        baseColor: [0.44, 0.45, 0.39, 1],
        pattern: "fine-galvanized",
        physicalScale: [12, 12],
        roughness: 0.72,
        metalness: 0.52,
        role: "dull process pipe"
    ),
]

private func argument(_ name: String, in arguments: [String]) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL3CohesionBuildError.arguments
    }
    return arguments[index + 1]
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func sha256(_ url: URL) throws -> String {
    sha256(try Data(contentsOf: url))
}

private func jsonData(_ object: Any) throws -> Data {
    var data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    return data
}

private func jsonObject(_ data: Data) throws -> [String: Any] {
    guard
        let object = try JSONSerialization.jsonObject(with: data)
            as? [String: Any]
    else {
        throw IndustrialL3CohesionBuildError.invalid(
            "expected a JSON object"
        )
    }
    return object
}

private func write(_ data: Data, to url: URL) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: url, options: .atomic)
}

private func transformedDescriptorValue(_ value: Any) throws -> Any {
    if var dictionary = value as? [String: Any] {
        for key in dictionary.keys.sorted() {
            guard let existing = dictionary[key] else {
                continue
            }
            if key.lowercased().hasSuffix("materialid"),
               let oldID = existing as? String,
               let treatment = materialTreatments[oldID] {
                dictionary[key] = treatment.newID
            } else {
                dictionary[key] = try transformedDescriptorValue(existing)
            }
        }
        return dictionary
    }
    if let array = value as? [Any] {
        return try array.map(transformedDescriptorValue)
    }
    return value
}

private func descriptorWithoutAuthorizedChanges(
    _ value: Any
) -> Any {
    if var dictionary = value as? [String: Any] {
        dictionary.removeValue(forKey: "sourceRevision")
        if var sampling = dictionary["sampling"] as? [String: Any] {
            sampling.removeValue(forKey: "sourceRevisionBinding")
            dictionary["sampling"] = sampling
        }
        for key in dictionary.keys.sorted() {
            guard let existing = dictionary[key] else {
                continue
            }
            if key.lowercased().hasSuffix("materialid") {
                dictionary.removeValue(forKey: key)
            } else {
                dictionary[key] =
                    descriptorWithoutAuthorizedChanges(existing)
            }
        }
        return dictionary
    }
    if let array = value as? [Any] {
        return array.map(descriptorWithoutAuthorizedChanges)
    }
    return value
}

private func materialReferenceIDs(in value: Any) -> Set<String> {
    if let dictionary = value as? [String: Any] {
        return dictionary.reduce(into: Set<String>()) { result, item in
            if item.key.lowercased().hasSuffix("materialid"),
               let id = item.value as? String {
                result.insert(id)
            } else {
                result.formUnion(materialReferenceIDs(in: item.value))
            }
        }
    }
    if let array = value as? [Any] {
        return array.reduce(into: Set<String>()) {
            $0.formUnion(materialReferenceIDs(in: $1))
        }
    }
    return []
}

private func decodedDescriptor(
    from object: [String: Any]
) throws -> SceneDescriptor {
    try JSONDecoder().decode(
        SceneDescriptor.self,
        from: JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
    )
}

private func requireResolverFailure(
    _ object: [String: Any],
    label: String
) throws -> String {
    do {
        _ = try DescriptorSamplingResolver.resolve(
            descriptor: decodedDescriptor(from: object)
        )
        throw IndustrialL3CohesionBuildError.invalid(
            "\(label) unexpectedly resolved"
        )
    } catch let error as SamplingContractError {
        return error.description
    }
}

private func luma(_ rgba: [Double]) -> Int {
    Int(
        (
            rgba[0] * 0.2126
                + rgba[1] * 0.7152
                + rgba[2] * 0.0722
        ) * 255
    )
}

private func step32Luma(_ rgba: [Double]) -> Int {
    let value = luma(rgba)
    return min(255, max(0, ((value + 8) / 32) * 32))
}

private func makeMaterialLibrary(
    from base: [String: Any]
) throws -> ([String: Any], [[String: Any]]) {
    guard let baseMaterials = base["materials"] as? [[String: Any]] else {
        throw IndustrialL3CohesionBuildError.invalid(
            "base materials missing"
        )
    }
    var ledger: [[String: Any]] = []
    let materials = try baseMaterials.map { material -> [String: Any] in
        guard
            let oldID = material["id"] as? String,
            let treatment = materialTreatments[oldID]
        else {
            throw IndustrialL3CohesionBuildError.invalid(
                "missing material treatment"
            )
        }
        var result = material
        result["id"] = treatment.newID
        result["baseColorRGBA"] = treatment.baseColor
        result["pattern"] = treatment.pattern
        result["physicalScaleWorld"] = treatment.physicalScale
        result["roughness"] = treatment.roughness
        result["metalness"] = treatment.metalness
        ledger.append([
            "oldID": oldID,
            "newID": treatment.newID,
            "role": treatment.role,
            "baseColorRGBA": treatment.baseColor,
            "pattern": treatment.pattern,
            "physicalScaleWorld": treatment.physicalScale,
            "predictedLuma": luma(treatment.baseColor),
            "predictedStep32Luma": step32Luma(treatment.baseColor),
        ])
        return result
    }
    var output = base
    output["libraryID"] = "industrial-l03-cohesion-east-v01"
    output["familyAnchorFile"] = baseRawRelative
    output["familyAnchorSHA256"] = baseRawSHA256
    output["imageGenMaterialSwatchesUsed"] = false
    output["materials"] = materials
    return (output, ledger.sorted {
        ($0["newID"] as? String ?? "") < ($1["newID"] as? String ?? "")
    })
}

private func createValueLadder(
    ledger: [[String: Any]],
    outputURL: URL
) throws {
    let width = 1200
    let rowHeight = 52
    let height = 80 + ledger.count * rowHeight
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw IndustrialL3CohesionBuildError.invalid(
            "could not allocate value ladder"
        )
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSColor(
        calibratedRed: 0.06,
        green: 0.07,
        blue: 0.08,
        alpha: 1
    ).setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    let titleAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.boldSystemFont(ofSize: 24),
        .foregroundColor: NSColor.white,
    ]
    let textAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
        .foregroundColor: NSColor.white,
    ]
    NSString(
        string:
            "Industrial L3 East A0 material/value/outline contract — pre-pixel"
    ).draw(
        at: NSPoint(x: 24, y: height - 44),
        withAttributes: titleAttributes
    )
    for (index, item) in ledger.enumerated() {
        guard
            let rgba = item["baseColorRGBA"] as? [Double],
            let id = item["newID"] as? String,
            let role = item["role"] as? String,
            let step = item["predictedStep32Luma"] as? Int
        else {
            continue
        }
        let y = height - 92 - (index * rowHeight)
        NSColor(
            calibratedRed: rgba[0],
            green: rgba[1],
            blue: rgba[2],
            alpha: 1
        ).setFill()
        NSRect(x: 24, y: y, width: 150, height: 34).fill()
        NSString(
            string: "\(id) | step32 \(step) | \(role)"
        ).draw(
            at: NSPoint(x: 192, y: y + 8),
            withAttributes: textAttributes
        )
    }
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw IndustrialL3CohesionBuildError.invalid(
            "could not encode value ladder"
        )
    }
    try write(png, to: outputURL)
}

@main
enum BuildIndustrialL3CohesionEastMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try argument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let outputRoot = URL(
            fileURLWithPath: try argument("--output-root", in: arguments)
        ).standardizedFileURL
        let regularFrame = URL(
            fileURLWithPath: try argument(
                "--regular-staged-frame",
                in: arguments
            )
        ).standardizedFileURL
        let compactFrame = URL(
            fileURLWithPath: try argument(
                "--compact-staged-frame",
                in: arguments
            )
        ).standardizedFileURL

        let baseDescriptorURL =
            repositoryRoot.appendingPathComponent(baseDescriptorRelative)
        let baseMaterialsURL =
            repositoryRoot.appendingPathComponent(baseMaterialsRelative)
        let baseRawURL =
            repositoryRoot.appendingPathComponent(baseRawRelative)
        guard
            try sha256(baseDescriptorURL) == baseDescriptorSHA256,
            try sha256(baseMaterialsURL) == baseMaterialsSHA256,
            try sha256(baseRawURL) == baseRawSHA256
        else {
            throw IndustrialL3CohesionBuildError.invalid(
                "accepted Industrial L3 East input hash drift"
            )
        }

        let baseDescriptorData = try Data(contentsOf: baseDescriptorURL)
        let baseDescriptorObject = try jsonObject(baseDescriptorData)
        let baseMaterialsObject = try jsonObject(
            Data(contentsOf: baseMaterialsURL)
        )
        var transformed = try transformedDescriptorValue(
            baseDescriptorObject
        ) as! [String: Any]
        transformed["sourceRevision"] = "source-v04"
        guard var sampling = transformed["sampling"] as? [String: Any] else {
            throw IndustrialL3CohesionBuildError.invalid(
                "sampling block missing"
            )
        }
        sampling["sourceRevisionBinding"] = "source-v04"
        transformed["sampling"] = sampling

        let baseCanonical = try jsonData(
            descriptorWithoutAuthorizedChanges(baseDescriptorObject)
        )
        let repairedCanonical = try jsonData(
            descriptorWithoutAuthorizedChanges(transformed)
        )
        guard baseCanonical == repairedCanonical else {
            throw IndustrialL3CohesionBuildError.invalid(
                "non-material geometry/registration descriptor drift"
            )
        }

        let (materialLibrary, ledger) = try makeMaterialLibrary(
            from: baseMaterialsObject
        )
        let materialData = try jsonData(materialLibrary)
        let descriptorData = try jsonData(transformed)
        let decodedDescriptor = try JSONDecoder().decode(
            SceneDescriptor.self,
            from: descriptorData
        )
        let effective = try DescriptorSamplingResolver.resolve(
            descriptor: decodedDescriptor
        )
        let acceptedEffective = try DescriptorSamplingResolver.resolve(
            descriptor: JSONDecoder().decode(
                SceneDescriptor.self,
                from: baseDescriptorData
            )
        )
        guard
            decodedDescriptor.logicalBuildingID == "industrial_l03",
            decodedDescriptor.variantID == "variant-0",
            decodedDescriptor.viewDirection == "east",
            decodedDescriptor.sourceRevision == "source-v04",
            decodedDescriptor.authoredIndependently,
            decodedDescriptor.registration.orientationTransform == "none",
            effective.contractID
                == DescriptorSamplingResolver.schema2ContractV3ID,
            effective.sceneKitAntialiasing == "none",
            effective.sceneKitShadows == "disabled",
            effective.sceneKitLightingMode == "authored-constant-v1",
            effective.preLanczosCanonicalizer == nil
        else {
            throw IndustrialL3CohesionBuildError.invalid(
                "East cohesion descriptor contract mismatch"
            )
        }

        let materialIDs = Set(
            (materialLibrary["materials"] as? [[String: Any]] ?? [])
                .compactMap { $0["id"] as? String }
        )
        let referenced = materialReferenceIDs(in: transformed)
        guard referenced.isSubset(of: materialIDs) else {
            throw IndustrialL3CohesionBuildError.invalid(
                "unresolved repaired material reference"
            )
        }

        let outputDescriptorURL =
            outputRoot.appendingPathComponent(outputDescriptorRelative)
        let outputMaterialsURL =
            outputRoot.appendingPathComponent(outputMaterialsRelative)
        let evidenceRoot =
            outputRoot.appendingPathComponent(evidenceRelative)
        guard
            !FileManager.default.fileExists(
                atPath: outputDescriptorURL.path
            ),
            !FileManager.default.fileExists(
                atPath: outputMaterialsURL.path
            ),
            !FileManager.default.fileExists(atPath: evidenceRoot.path)
        else {
            throw IndustrialL3CohesionBuildError.invalid(
                "output must be absent before build"
            )
        }
        try write(descriptorData, to: outputDescriptorURL)
        try write(materialData, to: outputMaterialsURL)

        let builderRelative =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/"
            + "BuildIndustrialL3CohesionEast.swift"
        let rendererArchitectureRelative =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/"
            + "RendererArchitecture.swift"
        let bins = Set(
            ledger.compactMap {
                $0["predictedStep32Luma"] as? Int
            }
        ).sorted()
        guard bins.count >= 6 else {
            throw IndustrialL3CohesionBuildError.invalid(
                "material value ladder has fewer than six bins"
            )
        }
        var wrongDirection = transformed
        wrongDirection["viewDirection"] = "north"
        var wrongRevision = transformed
        wrongRevision["sourceRevision"] = "source-v05"
        var wrongRevisionSampling =
            wrongRevision["sampling"] as! [String: Any]
        wrongRevisionSampling["sourceRevisionBinding"] = "source-v05"
        wrongRevision["sampling"] = wrongRevisionSampling
        var wrongLogicalID = transformed
        wrongLogicalID["logicalBuildingID"] = "industrial_l04"
        var wrongPurpose = transformed
        var wrongPurposeSampling =
            wrongPurpose["sampling"] as! [String: Any]
        wrongPurposeSampling["purpose"] = "diagnostic-regression"
        wrongPurpose["sampling"] = wrongPurposeSampling
        let failClosedResults = [
            "wrongDirection": try requireResolverFailure(
                wrongDirection,
                label: "wrong direction"
            ),
            "wrongRevision": try requireResolverFailure(
                wrongRevision,
                label: "wrong revision"
            ),
            "wrongLogicalBuildingID": try requireResolverFailure(
                wrongLogicalID,
                label: "wrong logical building ID"
            ),
            "wrongPurpose": try requireResolverFailure(
                wrongPurpose,
                label: "wrong purpose"
            ),
        ]
        let validation: [String: Any] = [
            "task": "PLAY-027",
            "program": "Wave-011-A0",
            "batch": "industrial-l03-cohesion-east-v01",
            "reviewAuthority":
                "single-direction-source-review-not-family-or-production-acceptance",
            "sourceAuthority": false,
            "productionSelected": false,
            "sourceProcesses": 0,
            "normalizerProcesses": 0,
            "imageGenCalls": 0,
            "baseDescriptorFile": baseDescriptorRelative,
            "baseDescriptorSHA256": baseDescriptorSHA256,
            "baseMaterialLibraryFile": baseMaterialsRelative,
            "baseMaterialLibrarySHA256": baseMaterialsSHA256,
            "baseImmutableRawFile": baseRawRelative,
            "baseImmutableRawSHA256": baseRawSHA256,
            "repairedDescriptorFile": outputDescriptorRelative,
            "repairedDescriptorSHA256": sha256(descriptorData),
            "repairedMaterialLibraryFile": outputMaterialsRelative,
            "repairedMaterialLibrarySHA256": sha256(materialData),
            "geometryRegistrationCanonicalSHA256":
                sha256(baseCanonical),
            "geometryRegistrationCanonicalIdentity": true,
            "cameraIdentity": true,
            "frontagePivotSocketShadowIdentity": true,
            "orientationTransform": "none",
            "authoredIndependently": true,
            "productionDecoderDryDecode": "pass",
            "samplingResolver": "schema-2-v3-east-only-pass",
            "acceptedSourceV02SamplingReproduction":
                acceptedEffective == effective,
            "samplingFailClosedResults": failClosedResults,
            "materialReferenceValidation": "pass",
            "materialTreatmentCount": ledger.count,
            "predictedStep32LumaBins": bins,
            "materialTreatmentLedger": ledger,
            "postProcessTintOrRecolorAlias": false,
            "treatmentScope":
                "new material IDs, patterns, physical scales, roughness, metalness, value hierarchy and structural edge roles on frozen geometry",
            "regularStagedFrame": [
                "externalFile": regularFrame.path,
                "sha256": try sha256(regularFrame),
            ],
            "compactStagedFrame": [
                "externalFile": compactFrame.path,
                "sha256": try sha256(compactFrame),
            ],
            "builderSourceFile": builderRelative,
            "builderSourceSHA256": try sha256(
                repositoryRoot.appendingPathComponent(builderRelative)
            ),
            "rendererArchitectureFile": rendererArchitectureRelative,
            "rendererArchitectureSHA256": try sha256(
                repositoryRoot.appendingPathComponent(
                    rendererArchitectureRelative
                )
            ),
            "firstPixelGate":
                "exactly one fresh East source-v04 process, then two no-Metal normalizations and source/native2x/compact/grayscale/composed-city review",
        ]
        try write(
            try jsonData(validation),
            to: evidenceRoot.appendingPathComponent(
                "PREPIXEL-VALIDATION.json"
            )
        )

        let contract = """
        # Industrial L3 East A0 material/value/outline contract

        **Authority:** analytic pre-pixel checkpoint only. No source, family,
        renderer, shipping, or production-selection acceptance.

        ## Frozen authored structure

        The accepted Industrial L3 East source-v02 descriptor is the immutable
        geometry and registration anchor. Source-v04 changes only the source
        revision binding and material references. Camera, 56×56 footprint,
        massing, four loading bays, control entrance, pivot, road socket,
        contact polygon, southeast authored shadow, and sampling pipeline remain
        byte-for-value identical. `orientationTransform` remains `none`.

        ## Cohesion treatment

        This is not a post-process tint and not a recolor-only alias. Every
        consumed material role receives a new fail-closed ID plus authored
        pattern, physical scale, roughness, metalness, and value target:

        - weathered blue production steel replaces clean cyan corrugation;
        - warm formed concrete and rusticated plinth replace chalky cream;
        - charcoal foundation, roof edge, frames, and recesses establish a
          shared one-pixel-at-compact structural outline hierarchy;
        - oxidized process metal and tanks create industrial surface depth;
        - low-glare roof/apron values keep the roof from becoming a white slab;
        - safety ochre remains subordinate to dock and control-frontage identity.

        The material ladder spans \(bins.count) predicted step-32 luma bins.
        Exact pixel values, accent share, outline survival, frontage contrast,
        compact-scale cohesion, and composed-city fit are deferred to one
        governed East source process. Any clinical/chalky read, lost dock
        rhythm, dark crush, halo, subpixel pattern instability, or mismatch
        beside the bound staged frames rejects the direction before siblings.
        """
        try write(
            Data((contract + "\n").utf8),
            to: evidenceRoot.appendingPathComponent(
                "MATERIAL-VALUE-OUTLINE-CONTRACT.md"
            )
        )

        let reviewRequest = """
        # Independent review request — Industrial L3 A0 East pre-pixel

        Review this checkpoint only as authority to attempt one East pixel
        process. Confirm that the new role-specific material system addresses
        the chalky imported look without changing accepted geometry,
        frontage, registration, or sampling. No North/South/West sibling,
        production selection, renderer ingestion, or shipping authority is
        requested.
        """
        try write(
            Data((reviewRequest + "\n").utf8),
            to: evidenceRoot.appendingPathComponent(
                "INDEPENDENT-REVIEW-REQUEST.md"
            )
        )
        try createValueLadder(
            ledger: ledger,
            outputURL: evidenceRoot.appendingPathComponent(
                "MATERIAL-VALUE-LADDER.png"
            )
        )

        print(
            "industrial-l03-cohesion-east-prepixel-pass "
                + evidenceRoot.appendingPathComponent(
                    "PREPIXEL-VALIDATION.json"
                ).path
        )
    }
}
