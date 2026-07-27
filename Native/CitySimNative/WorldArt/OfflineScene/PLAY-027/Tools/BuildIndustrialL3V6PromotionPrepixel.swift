import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum IndustrialL3V6PromotionError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return """
            usage: build-industrial-l3-v6-promotion-prepixel \
              --repository-root <path> --output-root <path> \
              --builder-binary <path> [--finalize \
              --structural-validator-binary <path>]
            """
        case let .invalid(message):
            return message
        }
    }
}

private struct DirectionContract {
    let direction: String
    let recipe: String
    let selectedCheckpoint: String
    let sourceDescriptor: String
    let sourceDescriptorSHA256: String
    let selectedMaterial: String
    let selectedMaterialSHA256: String
    let sceneGeometryID: String
    let materialChanges:
        [(materialID: String, channel: Int, deltaUnits: Int)]
}

private struct Box {
    let id: String
    let dimensions: [Double]
    let position: [Double]
    let materialID: String
}

private let authorityCommit =
    "42ca258f2e465699c6c589f6380e973d4592df61"
private let mergedCheckpoint =
    "bc52d32fea1d17814e6bb7af736f2fe8884a4bc2"
private let promotionAuthority =
    "docs/production/evidence/PLAY-027/"
    + "INDUSTRIAL-L03-SOURCE-V06-PROMOTION-AUTHORITY-86ae9c6.md"
private let toolSource =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/"
    + "BuildIndustrialL3V6PromotionPrepixel.swift"
private let structuralValidatorSource =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/"
    + "ValidateStructuralBoundaries.swift"
private let sourceStructuralReport =
    "docs/production/evidence/PLAY-027/industrial-l03/l03/"
    + "cohesion-a0-frontage-prepixel-v01/STRUCTURAL-BOUNDARIES.json"
private let baseMaterial =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/"
    + "industrial-l03-cohesion-east-v01/materials/"
    + "industrial-l03-cohesion-east-v01.json"
private let baseMaterialSHA256 =
    "f39bbf5914ba15f90f100bfed5ac65e537b5a6a62d677be82698ac89cf982b65"
private let candidateRoot =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/"
    + "industrial-l03-cohesion-source-v06-v01"
private let evidenceRoot =
    "docs/production/evidence/PLAY-027/industrial-l03/l03/"
    + "source-v06-promotion-prepixel-v01"
private let contracts = [
    DirectionContract(
        direction: "north",
        recipe: "N2",
        selectedCheckpoint:
            "86ae9c6e51f271988dbb3f84800f45fd4ed6375b",
        sourceDescriptor:
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "art-proof/industrial-l03-cohesion-frontage-v01/scenes/"
            + "industrial_l03/variant-0/north/scene.json",
        sourceDescriptorSHA256:
            "a147ad0a7023374b982a6677325da2912f45796616b03579e1a72eb7da4a6b61",
        selectedMaterial:
            "docs/production/evidence/PLAY-027/industrial-l03/l03/"
            + "source-v06-north-final-sensitivity-v01/diagnostics/N2/"
            + "inputs/N2/materials.json",
        selectedMaterialSHA256:
            "33ff7c3424594a05bf9eea94958f33e82f186b7ed5b99ea3d736b0852342dd58",
        sceneGeometryID:
            "industrial-l03-north-v06-open-loading-court",
        materialChanges: [
            ("l3c-charcoal-outline-steel", 0, 2),
            ("l3c-warm-trim", 0, 3),
        ]
    ),
    DirectionContract(
        direction: "west",
        recipe: "W1",
        selectedCheckpoint:
            "9a384ebceef0a4dadd64b980950d8fe2a9d4137e",
        sourceDescriptor:
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "art-proof/industrial-l03-cohesion-frontage-v01/scenes/"
            + "industrial_l03/variant-0/west/scene.json",
        sourceDescriptorSHA256:
            "56e9aef896ef5eef435f76ff466f837ac022ff18edbc4e6bd3fa24cb583d78dc",
        selectedMaterial:
            "docs/production/evidence/PLAY-027/industrial-l03/l03/"
            + "source-v06-sensitivity-matrix-v01/diagnostics/inputs/"
            + "W1/materials.json",
        selectedMaterialSHA256:
            "59a450c842058067d35374b041a4f5a263eb2ffb02c010e90bc156a1a3430d52",
        sceneGeometryID:
            "industrial-l03-west-v06-open-loading-court",
        materialChanges: [
            ("l3c-charcoal-outline-steel", 0, 2),
            ("l3c-warm-formed-concrete", 2, 2),
        ]
    ),
]

private func argument(_ name: String, in arguments: [String]) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL3V6PromotionError.arguments
    }
    return arguments[index + 1]
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func sha256(_ target: URL) throws -> String {
    sha256(try Data(contentsOf: target))
}

private func jsonObject(_ target: URL) throws -> [String: Any] {
    guard
        let value = try JSONSerialization.jsonObject(
            with: Data(contentsOf: target)
        ) as? [String: Any]
    else {
        throw IndustrialL3V6PromotionError.invalid(
            "JSON object expected: \(target.path)"
        )
    }
    return value
}

private func jsonData(_ object: Any) throws -> Data {
    var data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    return data
}

private func canonicalHash(_ object: Any) throws -> String {
    sha256(try jsonData(object))
}

private func write(_ data: Data, to target: URL) throws {
    guard !FileManager.default.fileExists(atPath: target.path) else {
        throw IndustrialL3V6PromotionError.invalid(
            "output must be absent: \(target.path)"
        )
    }
    try FileManager.default.createDirectory(
        at: target.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: target, options: .atomic)
}

private func writeJSON(_ object: Any, to target: URL) throws {
    try write(try jsonData(object), to: target)
}

private func writeText(_ text: String, to target: URL) throws {
    try write(Data((text + "\n").utf8), to: target)
}

private func relativePath(_ target: URL, root: URL) throws -> String {
    let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
    guard target.path.hasPrefix(prefix) else {
        throw IndustrialL3V6PromotionError.invalid(
            "path is outside root: \(target.path)"
        )
    }
    return String(target.path.dropFirst(prefix.count))
}

private func materialPath(_ direction: String) -> String {
    "\(candidateRoot)/materials/industrial-l03-source-v06-\(direction).json"
}

private func descriptorPath(_ direction: String) -> String {
    "\(candidateRoot)/scenes/industrial_l03/variant-0/"
        + "\(direction)/scene.json"
}

private func scalarEqual(_ first: Any, _ second: Any) -> Bool {
    guard
        let firstData = try? JSONSerialization.data(
            withJSONObject: [first],
            options: [.sortedKeys]
        ),
        let secondData = try? JSONSerialization.data(
            withJSONObject: [second],
            options: [.sortedKeys]
        )
    else {
        return false
    }
    return firstData == secondData
}

private func semanticDiff(
    _ first: Any?,
    _ second: Any?,
    path: String = ""
) -> [[String: Any]] {
    if let firstDictionary = first as? [String: Any],
       let secondDictionary = second as? [String: Any]
    {
        let keys = Set(firstDictionary.keys).union(secondDictionary.keys)
        return keys.sorted().flatMap { key in
            let childPath = path + "/" + key
            if firstDictionary[key] == nil || secondDictionary[key] == nil {
                return [[
                    "path": childPath,
                    "before": firstDictionary[key] ?? NSNull(),
                    "after": secondDictionary[key] ?? NSNull(),
                ]]
            }
            return semanticDiff(
                firstDictionary[key],
                secondDictionary[key],
                path: childPath
            )
        }
    }
    if let firstArray = first as? [Any],
       let secondArray = second as? [Any]
    {
        guard firstArray.count == secondArray.count else {
            return [[
                "path": path,
                "before": firstArray,
                "after": secondArray,
            ]]
        }
        return firstArray.indices.flatMap { index in
            semanticDiff(
                firstArray[index],
                secondArray[index],
                path: "\(path)[\(index)]"
            )
        }
    }
    guard let first, let second else {
        return [[
            "path": path,
            "before": first ?? NSNull(),
            "after": second ?? NSNull(),
        ]]
    }
    return scalarEqual(first, second)
        ? []
        : [["path": path, "before": first, "after": second]]
}

private func materialIndex(
    _ materialID: String,
    in object: [String: Any]
) throws -> Int {
    guard
        let materials = object["materials"] as? [[String: Any]],
        let index = materials.firstIndex(
            where: { $0["id"] as? String == materialID }
        )
    else {
        throw IndustrialL3V6PromotionError.invalid(
            "missing material: \(materialID)"
        )
    }
    return index
}

private func expectedMaterialDeltaPaths(
    contract: DirectionContract,
    base: [String: Any]
) throws -> Set<String> {
    try Set(contract.materialChanges.map {
        let index = try materialIndex($0.materialID, in: base)
        return "/materials[\(index)]/baseColorRGBA[\($0.channel)]"
    })
}

private func candidateMaterial(
    selected: [String: Any],
    contract: DirectionContract
) -> [String: Any] {
    var output = selected
    output["libraryID"] =
        "industrial-l03-source-v06-\(contract.direction)"
    output["provenance"] = [
        "authorityCommit": authorityCommit,
        "promotionAuthority": promotionAuthority,
        "selectedCheckpoint": contract.selectedCheckpoint,
        "selectedDiagnosticMaterial": contract.selectedMaterial,
        "selectedDiagnosticMaterialSHA256":
            contract.selectedMaterialSHA256,
        "selectedRecipe": contract.recipe,
        "sourceRevision": "source-v06",
        "viewDirection": contract.direction,
    ]
    return output
}

private func candidateDescriptor(
    source: [String: Any],
    materialFile: String,
    materialSHA256: String,
    contract: DirectionContract
) throws -> [String: Any] {
    guard
        source["sourceRevision"] as? String == "source-v05",
        source["viewDirection"] as? String == contract.direction,
        var library = source["materialLibrary"] as? [String: Any],
        var sampling = source["sampling"] as? [String: Any]
    else {
        throw IndustrialL3V6PromotionError.invalid(
            "\(contract.direction) frozen descriptor shape drift"
        )
    }
    var output = source
    output["sourceRevision"] = "source-v06"
    output["sceneGeometryID"] = contract.sceneGeometryID
    library["file"] = materialFile
    library["sha256"] = materialSHA256
    output["materialLibrary"] = library
    sampling["sourceRevisionBinding"] = "source-v06"
    output["sampling"] = sampling
    output["provenance"] = [
        "authorityCommit": authorityCommit,
        "promotionAuthority": promotionAuthority,
        "selectedCheckpoint": contract.selectedCheckpoint,
        "selectedDiagnosticMaterial": contract.selectedMaterial,
        "selectedDiagnosticMaterialSHA256":
            contract.selectedMaterialSHA256,
        "selectedRecipe": contract.recipe,
        "sourceDescriptor": contract.sourceDescriptor,
        "sourceDescriptorSHA256": contract.sourceDescriptorSHA256,
        "sourceRevisionBinding": "source-v06",
    ]
    return output
}

private func materialReferences(in value: Any) -> Set<String> {
    if let dictionary = value as? [String: Any] {
        return dictionary.reduce(into: Set<String>()) { result, item in
            if
                (item.key == "materialID"
                    || item.key.hasSuffix("MaterialID")),
                let materialID = item.value as? String
            {
                result.insert(materialID)
            }
            result.formUnion(materialReferences(in: item.value))
        }
    }
    if let array = value as? [Any] {
        return array.reduce(into: Set<String>()) {
            $0.formUnion(materialReferences(in: $1))
        }
    }
    return []
}

private func materialIDs(_ object: [String: Any]) throws -> Set<String> {
    guard let materials = object["materials"] as? [[String: Any]] else {
        throw IndustrialL3V6PromotionError.invalid(
            "material library missing materials"
        )
    }
    return Set(try materials.map {
        guard let id = $0["id"] as? String else {
            throw IndustrialL3V6PromotionError.invalid(
                "material missing id"
            )
        }
        return id
    })
}

private func validateBinding(
    descriptor: [String: Any],
    material: [String: Any],
    materialData: Data,
    expectedFile: String
) throws {
    guard
        let pointer = descriptor["materialLibrary"] as? [String: Any],
        pointer["file"] as? String == expectedFile,
        pointer["sha256"] as? String == sha256(materialData),
        materialReferences(in: descriptor).isSubset(of: try materialIDs(material))
    else {
        throw IndustrialL3V6PromotionError.invalid(
            "descriptor/library binding rejected"
        )
    }
}

private func hashSubset(
    _ object: [String: Any],
    keys: [String]
) throws -> String {
    try canonicalHash(
        Dictionary(uniqueKeysWithValues: keys.compactMap { key in
            object[key].map { (key, $0) }
        })
    )
}

private func samplingHash(_ object: [String: Any]) throws -> String {
    guard var sampling = object["sampling"] as? [String: Any] else {
        throw IndustrialL3V6PromotionError.invalid("sampling missing")
    }
    sampling.removeValue(forKey: "sourceRevisionBinding")
    return try canonicalHash(sampling)
}

private func frontageHash(_ object: [String: Any]) throws -> String {
    guard let registration = object["registration"] as? [String: Any] else {
        throw IndustrialL3V6PromotionError.invalid("registration missing")
    }
    let keys = [
        "groundPivotSource",
        "frontageSocketSource",
        "frontageEdgeSource",
        "doorBaseSource",
        "footprintPolygonSource",
        "contactPolygonWorld",
        "shadowEnvelopeSource",
        "orientationTransform",
    ]
    let frontage = Dictionary(
        uniqueKeysWithValues: keys.compactMap { key in
            registration[key].map { (key, $0) }
        })
    return try canonicalHash([
        "registration": frontage,
        "entrance": object["entrance"] ?? NSNull(),
    ])
}

private func boxes(_ descriptor: [String: Any]) throws -> [Box] {
    guard let building = descriptor["building"] as? [String: Any] else {
        throw IndustrialL3V6PromotionError.invalid("building missing")
    }
    var output: [Box] = []
    if
        let dimensions = building["foundationDimensions"] as? [Double],
        let position = building["foundationPositionWorld"] as? [Double],
        let material = building["foundationMaterialID"] as? String
    {
        output.append(
            Box(
                id: "foundation",
                dimensions: dimensions,
                position: position,
                materialID: material
            )
        )
    }
    for key in ["massBlocks", "roofVolumes", "trimBands"] {
        for value in building[key] as? [[String: Any]] ?? [] {
            guard
                let id = value["id"] as? String,
                let dimensions = value["dimensions"] as? [Double],
                let position = value["positionWorld"] as? [Double],
                let material = value["materialID"] as? String
            else {
                throw IndustrialL3V6PromotionError.invalid(
                    "\(key) primitive malformed"
                )
            }
            output.append(
                Box(
                    id: id,
                    dimensions: dimensions,
                    position: position,
                    materialID: material
                )
            )
        }
    }
    for value in descriptor["props"] as? [[String: Any]] ?? [] {
        guard
            let id = value["id"] as? String,
            let dimensions = value["dimensions"] as? [Double],
            let position = value["positionWorld"] as? [Double],
            let material = value["materialID"] as? String
        else {
            throw IndustrialL3V6PromotionError.invalid(
                "prop primitive malformed"
            )
        }
        output.append(
            Box(
                id: id,
                dimensions: dimensions,
                position: position,
                materialID: material
            )
        )
    }
    return output
}

private func rootBounds(_ values: [Box]) throws -> [[Double]] {
    guard !values.isEmpty else {
        throw IndustrialL3V6PromotionError.invalid("no geometry boxes")
    }
    let minimums = values.map {
        zip($0.position, $0.dimensions.map { $0 / 2 }).map(-)
    }
    let maximums = values.map {
        zip($0.position, $0.dimensions.map { $0 / 2 }).map(+)
    }
    return [
        [
            minimums.map { $0[0] }.min()!,
            minimums.map { $0[1] }.min()!,
            minimums.map { $0[2] }.min()!,
        ],
        [
            maximums.map { $0[0] }.max()!,
            maximums.map { $0[1] }.max()!,
            maximums.map { $0[2] }.max()!,
        ],
    ]
}

private func materialAssignmentHash(_ values: [Box]) throws -> String {
    try canonicalHash(
        values.sorted { $0.id < $1.id }.map {
            ["id": $0.id, "materialID": $0.materialID]
        }
    )
}

private func normalizedStructuralHash(
    _ object: [String: Any]
) throws -> String {
    guard var directions = object["directions"] as? [[String: Any]] else {
        throw IndustrialL3V6PromotionError.invalid(
            "structural report missing directions"
        )
    }
    for index in directions.indices {
        directions[index].removeValue(forKey: "sceneFile")
        directions[index].removeValue(forKey: "sceneGeometryID")
        directions[index].removeValue(forKey: "sourceRevision")
    }
    var normalized = object
    normalized["directions"] = directions
    return try canonicalHash(normalized)
}

private func colorRecords(
    _ material: [String: Any]
) throws -> [(id: String, rgba: [UInt8])] {
    guard let values = material["materials"] as? [[String: Any]] else {
        throw IndustrialL3V6PromotionError.invalid("materials missing")
    }
    return try values.map { value in
        guard
            let id = value["id"] as? String,
            let color = value["baseColorRGBA"] as? [Double],
            color.count == 4
        else {
            throw IndustrialL3V6PromotionError.invalid(
                "material color malformed"
            )
        }
        return (
            id,
            color.map {
                UInt8(clamping: Int(($0 * 255).rounded()))
            }
        )
    }
}

private func image(
    width: Int,
    height: Int,
    pixels: [UInt8]
) throws -> CGImage {
    guard
        let provider = CGDataProvider(data: Data(pixels) as CFData),
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
        let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(
                rawValue:
                    CGImageAlphaInfo.premultipliedLast.rawValue
            ),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    else {
        throw IndustrialL3V6PromotionError.invalid("image creation failed")
    }
    return image
}

private func writePNG(_ image: CGImage, to target: URL) throws {
    guard !FileManager.default.fileExists(atPath: target.path) else {
        throw IndustrialL3V6PromotionError.invalid(
            "output must be absent: \(target.path)"
        )
    }
    try FileManager.default.createDirectory(
        at: target.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    guard
        let destination = CGImageDestinationCreateWithURL(
            target as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        )
    else {
        throw IndustrialL3V6PromotionError.invalid(
            "PNG destination failed"
        )
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw IndustrialL3V6PromotionError.invalid("PNG finalize failed")
    }
}

private func grayscale(_ rgba: [UInt8]) -> [UInt8] {
    let red = 0.2126 * Double(rgba[0])
    let green = 0.7152 * Double(rgba[1])
    let blue = 0.0722 * Double(rgba[2])
    let value = UInt8(clamping: Int((red + green + blue).rounded()))
    return [value, value, value, rgba[3]]
}

private func swatchImage(
    colors: [(id: String, rgba: [UInt8])],
    native: Bool
) throws -> CGImage {
    let width = native ? colors.count * 16 : 512
    let height = native ? 32 : colors.count * 40
    var pixels = Array(repeating: UInt8(24), count: width * height * 4)
    for index in stride(from: 3, to: pixels.count, by: 4) {
        pixels[index] = 255
    }
    func fill(
        x0: Int,
        x1: Int,
        y0: Int,
        y1: Int,
        color: [UInt8]
    ) {
        for y in max(0, y0)..<min(height, y1) {
            for x in max(0, x0)..<min(width, x1) {
                let offset = (y * width + x) * 4
                pixels.replaceSubrange(offset..<(offset + 4), with: color)
            }
        }
    }
    for (index, value) in colors.enumerated() {
        if native {
            fill(
                x0: index * 16,
                x1: index * 16 + 15,
                y0: 0,
                y1: 15,
                color: value.rgba
            )
            fill(
                x0: index * 16,
                x1: index * 16 + 15,
                y0: 17,
                y1: 32,
                color: grayscale(value.rgba)
            )
        } else {
            fill(
                x0: 0,
                x1: 252,
                y0: index * 40,
                y1: index * 40 + 38,
                color: value.rgba
            )
            fill(
                x0: 260,
                x1: width,
                y0: index * 40,
                y1: index * 40 + 38,
                color: grayscale(value.rgba)
            )
        }
    }
    return try image(width: width, height: height, pixels: pixels)
}

private func build(
    repositoryRoot: URL,
    outputRoot: URL,
    builderBinary: URL
) throws {
    let authorityURL = repositoryRoot.appendingPathComponent(
        promotionAuthority
    )
    let baseMaterialURL = repositoryRoot.appendingPathComponent(baseMaterial)
    let toolURL = repositoryRoot.appendingPathComponent(toolSource)
    guard
        try sha256(authorityURL)
            == "56f419be5e2eab8f7ddac0c72d17a3a862f8c7c8fcf775e2e194762bf1b18929",
        try sha256(baseMaterialURL) == baseMaterialSHA256,
        FileManager.default.isExecutableFile(atPath: builderBinary.path)
    else {
        throw IndustrialL3V6PromotionError.invalid(
            "authority, base material, or builder binary drift"
        )
    }
    let baseMaterialObject = try jsonObject(baseMaterialURL)
    var semanticRecords: [[String: Any]] = []
    var replayRecords: [[String: Any]] = []
    var negativeRecords: [[String: Any]] = []
    var candidateMaterials: [String: ([String: Any], Data)] = [:]
    var candidateDescriptors: [String: ([String: Any], Data)] = [:]
    var swatchRecords: [[String: Any]] = []

    for contract in contracts {
        let sourceDescriptorURL = repositoryRoot.appendingPathComponent(
            contract.sourceDescriptor
        )
        let selectedMaterialURL = repositoryRoot.appendingPathComponent(
            contract.selectedMaterial
        )
        guard
            try sha256(sourceDescriptorURL)
                == contract.sourceDescriptorSHA256,
            try sha256(selectedMaterialURL)
                == contract.selectedMaterialSHA256
        else {
            throw IndustrialL3V6PromotionError.invalid(
                "\(contract.direction) frozen input hash drift"
            )
        }
        let sourceDescriptor = try jsonObject(sourceDescriptorURL)
        let selectedMaterial = try jsonObject(selectedMaterialURL)
        let material = candidateMaterial(
            selected: selectedMaterial,
            contract: contract
        )
        let materialData = try jsonData(material)
        let candidateMaterialRelative = materialPath(contract.direction)
        let candidateMaterialURL = outputRoot.appendingPathComponent(
            candidateMaterialRelative
        )
        try write(materialData, to: candidateMaterialURL)

        let descriptor = try candidateDescriptor(
            source: sourceDescriptor,
            materialFile: candidateMaterialRelative,
            materialSHA256: sha256(materialData),
            contract: contract
        )
        let descriptorData = try jsonData(descriptor)
        _ = try JSONDecoder().decode(
            SceneDescriptor.self,
            from: descriptorData
        )
        let candidateDescriptorRelative = descriptorPath(
            contract.direction
        )
        let candidateDescriptorURL = outputRoot.appendingPathComponent(
            candidateDescriptorRelative
        )
        try write(descriptorData, to: candidateDescriptorURL)
        try validateBinding(
            descriptor: descriptor,
            material: material,
            materialData: materialData,
            expectedFile: candidateMaterialRelative
        )

        let baseToSelected = semanticDiff(
            baseMaterialObject,
            selectedMaterial
        )
        let expectedDeltaPaths = try expectedMaterialDeltaPaths(
            contract: contract,
            base: baseMaterialObject
        )
        guard Set(baseToSelected.compactMap { $0["path"] as? String })
            == expectedDeltaPaths
        else {
            throw IndustrialL3V6PromotionError.invalid(
                "\(contract.direction) selected material semantic drift"
            )
        }
        let selectedToCandidate = semanticDiff(
            selectedMaterial,
            material
        )
        guard
            Set(selectedToCandidate.compactMap { $0["path"] as? String })
                == Set(["/libraryID", "/provenance"])
        else {
            throw IndustrialL3V6PromotionError.invalid(
                "\(contract.direction) library identity diff drift"
            )
        }
        let descriptorDiff = semanticDiff(sourceDescriptor, descriptor)
        let authorizedDescriptorPaths: Set<String> = [
            "/sourceRevision",
            "/sceneGeometryID",
            "/materialLibrary/file",
            "/materialLibrary/sha256",
            "/sampling/sourceRevisionBinding",
            "/provenance",
        ]
        guard
            Set(descriptorDiff.compactMap { $0["path"] as? String })
                == authorizedDescriptorPaths
        else {
            throw IndustrialL3V6PromotionError.invalid(
                "\(contract.direction) descriptor semantic diff drift"
            )
        }

        let sourceBoxes = try boxes(sourceDescriptor)
        let candidateBoxes = try boxes(descriptor)
        let geometryKeys = [
            "building",
            "entrance",
            "facades",
            "props",
            "occlusionExclusions",
            "derivation",
            "authoredIndependently",
        ]
        let sourceGeometryHash = try hashSubset(
            sourceDescriptor,
            keys: geometryKeys
        )
        let candidateGeometryHash = try hashSubset(
            descriptor,
            keys: geometryKeys
        )
        let sourceRegistrationHash = try hashSubset(
            sourceDescriptor,
            keys: ["registration"]
        )
        let candidateRegistrationHash = try hashSubset(
            descriptor,
            keys: ["registration"]
        )
        guard
            sourceGeometryHash == candidateGeometryHash,
            sourceRegistrationHash == candidateRegistrationHash,
            try frontageHash(sourceDescriptor)
                == frontageHash(descriptor),
            try samplingHash(sourceDescriptor)
                == samplingHash(descriptor),
            try hashSubset(sourceDescriptor, keys: ["camera", "light"])
                == hashSubset(descriptor, keys: ["camera", "light"]),
            try rootBounds(sourceBoxes) == rootBounds(candidateBoxes),
            try materialAssignmentHash(sourceBoxes)
                == materialAssignmentHash(candidateBoxes)
        else {
            throw IndustrialL3V6PromotionError.invalid(
                "\(contract.direction) replay invariant drift"
            )
        }

        semanticRecords.append([
            "direction": contract.direction,
            "recipe": contract.recipe,
            "sourceV05Descriptor": contract.sourceDescriptor,
            "sourceV05DescriptorSHA256":
                contract.sourceDescriptorSHA256,
            "sourceV05Material": baseMaterial,
            "sourceV05MaterialSHA256": baseMaterialSHA256,
            "selectedDiagnosticMaterial": contract.selectedMaterial,
            "selectedDiagnosticMaterialSHA256":
                contract.selectedMaterialSHA256,
            "candidateDescriptor": candidateDescriptorRelative,
            "candidateDescriptorSHA256": sha256(descriptorData),
            "candidateMaterial": candidateMaterialRelative,
            "candidateMaterialSHA256": sha256(materialData),
            "sourceToSelectedMaterialDiff": baseToSelected,
            "selectedToCandidateMaterialDiff": selectedToCandidate,
            "sourceToCandidateDescriptorDiff": descriptorDiff,
            "passed": true,
        ])
        replayRecords.append([
            "direction": contract.direction,
            "sceneGeometryID": contract.sceneGeometryID,
            "geometryHashSourceV05": sourceGeometryHash,
            "geometryHashSourceV06": candidateGeometryHash,
            "registrationHashSourceV05": sourceRegistrationHash,
            "registrationHashSourceV06": candidateRegistrationHash,
            "frontageHashSourceV05":
                try frontageHash(sourceDescriptor),
            "frontageHashSourceV06": try frontageHash(descriptor),
            "samplingEffectiveHashSourceV05":
                try samplingHash(sourceDescriptor),
            "samplingEffectiveHashSourceV06":
                try samplingHash(descriptor),
            "cameraLightShadowHashSourceV05":
                try hashSubset(
                    sourceDescriptor,
                    keys: ["camera", "light"]
                ),
            "cameraLightShadowHashSourceV06":
                try hashSubset(descriptor, keys: ["camera", "light"]),
            "materialAssignmentHashSourceV05":
                try materialAssignmentHash(sourceBoxes),
            "materialAssignmentHashSourceV06":
                try materialAssignmentHash(candidateBoxes),
            "rootBoundsWorldSourceV05": try rootBounds(sourceBoxes),
            "rootBoundsWorldSourceV06": try rootBounds(candidateBoxes),
            "productionDecode": "pass",
            "geometryFrontageRegistrationSamplingReplay": "pass",
            "productionSelected": false,
        ])
        let colors = try colorRecords(material)
        let enlargedRelative =
            "\(evidenceRoot)/review/"
            + "\(contract.direction.uppercased())-MATERIAL-SWATCH-"
            + "ENLARGED-COLOR-GRAYSCALE.png"
        let nativeRelative =
            "\(evidenceRoot)/review/"
            + "\(contract.direction.uppercased())-MATERIAL-SWATCH-"
            + "NATIVE-COLOR-GRAYSCALE.png"
        try writePNG(
            try swatchImage(colors: colors, native: false),
            to: outputRoot.appendingPathComponent(enlargedRelative)
        )
        try writePNG(
            try swatchImage(colors: colors, native: true),
            to: outputRoot.appendingPathComponent(nativeRelative)
        )
        swatchRecords.append([
            "direction": contract.direction,
            "materialOrder": colors.map(\.id),
            "enlargedPanel": enlargedRelative,
            "enlargedPanelSHA256": try sha256(
                outputRoot.appendingPathComponent(enlargedRelative)
            ),
            "nativePanel": nativeRelative,
            "nativePanelSHA256": try sha256(
                outputRoot.appendingPathComponent(nativeRelative)
            ),
            "columnOrBandOrder": ["color", "grayscale"],
        ])
        candidateMaterials[contract.direction] = (material, materialData)
        candidateDescriptors[contract.direction] =
            (descriptor, descriptorData)
    }

    guard
        let northMaterial = candidateMaterials["north"],
        let westMaterial = candidateMaterials["west"],
        let northDescriptor = candidateDescriptors["north"],
        let westDescriptor = candidateDescriptors["west"],
        sha256(northMaterial.1) != sha256(westMaterial.1),
        materialPath("north") != materialPath("west")
    else {
        throw IndustrialL3V6PromotionError.invalid(
            "direction-scoped libraries aliased"
        )
    }
    for value in [
        (
            "north-descriptor-with-west-library",
            northDescriptor.0,
            westMaterial,
            materialPath("north")
        ),
        (
            "west-descriptor-with-north-library",
            westDescriptor.0,
            northMaterial,
            materialPath("west")
        ),
    ] {
        do {
            try validateBinding(
                descriptor: value.1,
                material: value.2.0,
                materialData: value.2.1,
                expectedFile: value.3
            )
            throw IndustrialL3V6PromotionError.invalid(
                "\(value.0) unexpectedly passed"
            )
        } catch let error as IndustrialL3V6PromotionError {
            guard error.description == "descriptor/library binding rejected"
            else {
                throw error
            }
            negativeRecords.append([
                "case": value.0,
                "result": "EXPECTED_REJECTION",
                "reason": error.description,
            ])
        }
    }

    let evidenceURL = outputRoot.appendingPathComponent(evidenceRoot)
    try writeJSON([
        "task": "PLAY-027",
        "authorityCommit": authorityCommit,
        "disposition": "PREPIXEL_SEMANTIC_DIFF_PASS",
        "directions": semanticRecords,
        "sceneKitProcesses": 0,
        "rawProcesses": 0,
        "normalizerProcesses": 0,
        "sourceAuthority": false,
        "familyAuthority": false,
        "productionSelected": false,
    ], to: evidenceURL.appendingPathComponent("SEMANTIC-DIFF.json"))
    try writeJSON([
        "task": "PLAY-027",
        "authorityCommit": authorityCommit,
        "directions": replayRecords,
        "directionScopedLibrariesDistinct": true,
        "swatches": swatchRecords,
        "sceneKitProcesses": 0,
        "rawProcesses": 0,
        "normalizerProcesses": 0,
        "sourceAuthority": false,
        "familyAuthority": false,
        "productionSelected": false,
    ], to: evidenceURL.appendingPathComponent("REPLAY-VALIDATION.json"))
    try writeJSON([
        "task": "PLAY-027",
        "authorityCommit": authorityCommit,
        "cases": negativeRecords,
        "allSwappedLibrariesRejected": negativeRecords.count == 2,
        "productionSelected": false,
    ], to: evidenceURL.appendingPathComponent(
        "SWAPPED-LIBRARY-NEGATIVE.json"
    ))
    let request = """
    # PLAY-027 Industrial L3 source-v06 pre-pixel review request

    Integration authority: `\(authorityCommit)`.

    North promotes exact N2 material semantics into a direction-scoped
    source-v06 library. West promotes exact W1 semantics into a different
    direction-scoped source-v06 library. Source-v05 geometry, frontage,
    pivot, socket, registration, bounds, light/shadow, material assignments,
    and the effective sampling contract are unchanged.

    Review the semantic diff, structural replay, swapped-library rejection,
    enlarged swatches, and native-scale color/grayscale swatches. This
    checkpoint has zero SceneKit, raw, and normalizer processes.

    `sourceAuthority=false`
    `familyAuthority=false`
    `productionSelected=false`
    """
    try writeText(
        request,
        to: evidenceURL.appendingPathComponent(
            "INDEPENDENT-REVIEW-REQUEST.md"
        )
    )
    guard FileManager.default.fileExists(atPath: toolURL.path) else {
        throw IndustrialL3V6PromotionError.invalid("tool source missing")
    }
    print("PASS built North/West source-v06 pre-pixel promotion inputs")
}

private func finalize(
    repositoryRoot: URL,
    outputRoot: URL,
    builderBinary: URL,
    structuralValidatorBinary: URL
) throws {
    let evidenceURL = outputRoot.appendingPathComponent(evidenceRoot)
    let structuralURL = evidenceURL.appendingPathComponent(
        "STRUCTURAL-BOUNDARIES.json"
    )
    let structural = try jsonObject(structuralURL)
    let sourceStructuralURL = repositoryRoot.appendingPathComponent(
        sourceStructuralReport
    )
    let sourceStructural = try jsonObject(sourceStructuralURL)
    let sourceStructuralSemanticHash = try normalizedStructuralHash(
        sourceStructural
    )
    let candidateStructuralSemanticHash = try normalizedStructuralHash(
        structural
    )
    guard
        structural["passed"] as? Bool == true,
        (structural["failures"] as? [Any])?.isEmpty == true,
        sourceStructuralSemanticHash == candidateStructuralSemanticHash
    else {
        throw IndustrialL3V6PromotionError.invalid(
            "structural boundary replay failed"
        )
    }
    var descriptorRecords: [[String: Any]] = []
    var materialRecords: [[String: Any]] = []
    for contract in contracts {
        let descriptorRelative = descriptorPath(contract.direction)
        let materialRelative = materialPath(contract.direction)
        let descriptorURL = outputRoot.appendingPathComponent(
            descriptorRelative
        )
        let materialURL = outputRoot.appendingPathComponent(materialRelative)
        let descriptor = try jsonObject(descriptorURL)
        let material = try jsonObject(materialURL)
        let materialData = try Data(contentsOf: materialURL)
        try validateBinding(
            descriptor: descriptor,
            material: material,
            materialData: materialData,
            expectedFile: materialRelative
        )
        guard
            descriptor["sourceRevision"] as? String == "source-v06",
            descriptor["sceneGeometryID"] as? String
                == contract.sceneGeometryID,
            descriptor["productionSelected"] as? Bool == false
        else {
            throw IndustrialL3V6PromotionError.invalid(
                "\(contract.direction) final identity drift"
            )
        }
        descriptorRecords.append([
            "direction": contract.direction,
            "path": descriptorRelative,
            "sha256": try sha256(descriptorURL),
            "sceneGeometryID": contract.sceneGeometryID,
        ])
        materialRecords.append([
            "direction": contract.direction,
            "path": materialRelative,
            "sha256": try sha256(materialURL),
            "libraryID":
                material["libraryID"] as? String ?? "missing",
        ])
    }
    let evidenceFiles = [
        "SEMANTIC-DIFF.json",
        "REPLAY-VALIDATION.json",
        "SWAPPED-LIBRARY-NEGATIVE.json",
        "STRUCTURAL-BOUNDARIES.json",
        "INDEPENDENT-REVIEW-REQUEST.md",
        "review/NORTH-MATERIAL-SWATCH-ENLARGED-COLOR-GRAYSCALE.png",
        "review/NORTH-MATERIAL-SWATCH-NATIVE-COLOR-GRAYSCALE.png",
        "review/WEST-MATERIAL-SWATCH-ENLARGED-COLOR-GRAYSCALE.png",
        "review/WEST-MATERIAL-SWATCH-NATIVE-COLOR-GRAYSCALE.png",
    ]
    let evidenceInventory = try evidenceFiles.map { path in
        [
            "path": "\(evidenceRoot)/\(path)",
            "sha256": try sha256(
                evidenceURL.appendingPathComponent(path)
            ),
        ]
    }
    let receipt: [String: Any] = [
        "task": "PLAY-027",
        "authorityCommit": authorityCommit,
        "mergeCheckpoint": mergedCheckpoint,
        "disposition": "PREPIXEL_SOURCE_V06_PROMOTION_PASS",
        "logicalBuildingID": "industrial_l03",
        "variantID": "variant-0",
        "sourceRevision": "source-v06",
        "authorizedDirections": ["north", "west"],
        "descriptors": descriptorRecords,
        "materials": materialRecords,
        "tooling": [
            "builderSource": toolSource,
            "builderSourceSHA256": try sha256(
                repositoryRoot.appendingPathComponent(toolSource)
            ),
            "builderBinarySHA256": try sha256(builderBinary),
            "structuralValidatorSource": structuralValidatorSource,
            "structuralValidatorSourceSHA256": try sha256(
                repositoryRoot.appendingPathComponent(
                    structuralValidatorSource
                )
            ),
            "structuralValidatorBinarySHA256":
                try sha256(structuralValidatorBinary),
        ],
        "evidenceInventory": evidenceInventory,
        "semanticDiffPassed": true,
        "geometryFrontageRegistrationSamplingReplayPassed": true,
        "structuralBoundaryReplayPassed": true,
        "structuralReplay": [
            "sourceReport": sourceStructuralReport,
            "sourceReportSHA256": try sha256(sourceStructuralURL),
            "sourceSemanticSHA256": sourceStructuralSemanticHash,
            "candidateReport":
                "\(evidenceRoot)/STRUCTURAL-BOUNDARIES.json",
            "candidateReportSHA256": try sha256(structuralURL),
            "candidateSemanticSHA256":
                candidateStructuralSemanticHash,
            "identityOnlyFieldsExcluded": [
                "sceneFile",
                "sceneGeometryID",
                "sourceRevision",
            ],
            "semanticReportIdentity": true,
        ],
        "swappedLibraryRejectionPassed": true,
        "directionScopedLibrariesDistinct": true,
        "sceneKitProcesses": 0,
        "rawProcesses": 0,
        "normalizerProcesses": 0,
        "sourceAuthority": false,
        "familyAuthority": false,
        "productionSelected": false,
        "nextGate": "independent pre-pixel integration review",
    ]
    try writeJSON(
        receipt,
        to: evidenceURL.appendingPathComponent(
            "PREPIXEL-VALIDATION.json"
        )
    )
    print("PASS finalized source-v06 pre-pixel promotion evidence")
}

@main
private enum BuildIndustrialL3V6PromotionPrepixel {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try argument(
                "--repository-root",
                in: arguments
            ),
            isDirectory: true
        ).standardizedFileURL
        let outputRoot = URL(
            fileURLWithPath: try argument(
                "--output-root",
                in: arguments
            ),
            isDirectory: true
        ).standardizedFileURL
        let builderBinary = URL(
            fileURLWithPath: try argument(
                "--builder-binary",
                in: arguments
            )
        ).standardizedFileURL
        if arguments.contains("--finalize") {
            let structuralValidatorBinary = URL(
                fileURLWithPath: try argument(
                    "--structural-validator-binary",
                    in: arguments
                )
            ).standardizedFileURL
            try finalize(
                repositoryRoot: repositoryRoot,
                outputRoot: outputRoot,
                builderBinary: builderBinary,
                structuralValidatorBinary: structuralValidatorBinary
            )
        } else {
            try build(
                repositoryRoot: repositoryRoot,
                outputRoot: outputRoot,
                builderBinary: builderBinary
            )
        }
    }
}
