import CryptoKit
import Foundation

private enum RepairError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: build-industrial-l4-v18-foundation-repair --repository-root <path> --output-root <path>"
        case let .invalid(message):
            return message
        }
    }
}

private let sourceRevision = "source-v18-prepixel"
private let sceneGeometryID =
    "industrial-l04-crucible-gantry-v18-north-single-foundation"
private let sourceDescriptorPath =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/"
    + "industrial-l04-crucible-gantry-v17-north-prepixel/artifact/scenes/"
    + "industrial_l04/variant-0/n/scene.json"
private let outputDescriptorPath =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/"
    + "industrial-l04-crucible-gantry-v18-north-prepixel/artifact/scenes/"
    + "industrial_l04/variant-0/n/scene.json"

private func argument(_ name: String) throws -> String {
    guard
        let index = CommandLine.arguments.firstIndex(of: name),
        index + 1 < CommandLine.arguments.count
    else {
        throw RepairError.arguments
    }
    return CommandLine.arguments[index + 1]
}

private func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func canonicalData(_ object: Any) throws -> Data {
    try JSONSerialization.data(
        withJSONObject: object,
        options: [.sortedKeys, .withoutEscapingSlashes]
    )
}

private func prettyData(_ object: Any) throws -> Data {
    try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
}

private func dictionary(
    _ value: Any?,
    _ label: String
) throws -> [String: Any] {
    guard let result = value as? [String: Any] else {
        throw RepairError.invalid("\(label) is missing or invalid")
    }
    return result
}

private func array(
    _ value: Any?,
    _ label: String
) throws -> [[String: Any]] {
    guard let result = value as? [[String: Any]] else {
        throw RepairError.invalid("\(label) is missing or invalid")
    }
    return result
}

private func requireEqual(_ lhs: Any?, _ rhs: Any?, _ label: String) throws {
    guard
        let lhs,
        let rhs,
        try canonicalData(lhs) == canonicalData(rhs)
    else {
        throw RepairError.invalid("\(label) differs")
    }
}

@main
private enum BuildRepair {
    static func main() throws {
        let repositoryRoot = URL(fileURLWithPath: try argument("--repository-root"))
        let outputRoot = URL(fileURLWithPath: try argument("--output-root"))
        guard !FileManager.default.fileExists(atPath: outputRoot.path) else {
            throw RepairError.invalid("output root must be absent")
        }
        let sourceURL = repositoryRoot.appendingPathComponent(sourceDescriptorPath)
        let outputURL = repositoryRoot.appendingPathComponent(outputDescriptorPath)
        guard !FileManager.default.fileExists(atPath: outputURL.path) else {
            throw RepairError.invalid("immutable v18 descriptor already exists")
        }
        let sourceBytes = try Data(contentsOf: sourceURL)
        guard var root = try JSONSerialization.jsonObject(
            with: sourceBytes
        ) as? [String: Any] else {
            throw RepairError.invalid("could not decode source descriptor")
        }
        let originalRoot = root
        var building = try dictionary(root["building"], "building")
        let massBlocks = try array(building["massBlocks"], "building.massBlocks")
        let duplicateMatches = massBlocks.enumerated().filter {
            $0.element["id"] as? String == "v16-foundation"
        }
        guard duplicateMatches.count == 1 else {
            throw RepairError.invalid("expected exactly one v16-foundation")
        }
        let duplicateIndex = duplicateMatches[0].offset
        let duplicate = duplicateMatches[0].element
        let canonicalFoundation: [String: Any] = [
            "dimensions": building["foundationDimensions"] as Any,
            "positionWorld": building["foundationPositionWorld"] as Any,
            "materialID": building["foundationMaterialID"] as Any,
        ]
        let duplicateComparable: [String: Any] = [
            "dimensions": duplicate["dimensions"] as Any,
            "positionWorld": duplicate["positionWorld"] as Any,
            "materialID": duplicate["materialID"] as Any,
        ]
        let canonicalBytes = try canonicalData(canonicalFoundation)
        let duplicateBytes = try canonicalData(duplicateComparable)
        guard canonicalBytes == duplicateBytes else {
            throw RepairError.invalid(
                "canonical foundation and v16-foundation are not byte-equal"
            )
        }

        var repairedMassBlocks = massBlocks
        repairedMassBlocks.remove(at: duplicateIndex)
        building["massBlocks"] = repairedMassBlocks
        root["building"] = building
        root["sourceRevision"] = sourceRevision
        root["sceneGeometryID"] = sceneGeometryID
        var sampling = try dictionary(root["sampling"], "sampling")
        sampling["sourceRevisionBinding"] = sourceRevision
        root["sampling"] = sampling

        var reconstructed = root
        var reconstructedBuilding = try dictionary(
            reconstructed["building"],
            "reconstructed building"
        )
        var reconstructedMassBlocks = try array(
            reconstructedBuilding["massBlocks"],
            "reconstructed mass blocks"
        )
        reconstructedMassBlocks.insert(duplicate, at: duplicateIndex)
        reconstructedBuilding["massBlocks"] = reconstructedMassBlocks
        reconstructed["building"] = reconstructedBuilding
        reconstructed["sourceRevision"] = originalRoot["sourceRevision"]
        reconstructed["sceneGeometryID"] = originalRoot["sceneGeometryID"]
        var reconstructedSampling = try dictionary(
            reconstructed["sampling"],
            "reconstructed sampling"
        )
        let originalSampling = try dictionary(
            originalRoot["sampling"],
            "original sampling"
        )
        reconstructedSampling["sourceRevisionBinding"] =
            originalSampling["sourceRevisionBinding"]
        reconstructed["sampling"] = reconstructedSampling
        guard
            try canonicalData(reconstructed) == canonicalData(originalRoot)
        else {
            throw RepairError.invalid(
                "repair changed fields outside redundant mass and identity binding"
            )
        }

        try requireEqual(
            root["materialLibrary"],
            originalRoot["materialLibrary"],
            "material library"
        )
        for field in [
            "camera", "registration", "lighting", "authoredShadow",
            "contactPolygon", "footprint", "frontage", "derivation",
        ] {
            if originalRoot[field] != nil || root[field] != nil {
                try requireEqual(root[field], originalRoot[field], field)
            }
        }
        var comparableSampling = sampling
        comparableSampling["sourceRevisionBinding"] =
            originalSampling["sourceRevisionBinding"]
        guard
            try canonicalData(comparableSampling)
                == canonicalData(originalSampling)
        else {
            throw RepairError.invalid("sampling changed beyond revision binding")
        }

        let outputBytes = try prettyData(root)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try outputBytes.write(to: outputURL, options: .atomic)
        try FileManager.default.createDirectory(
            at: outputRoot,
            withIntermediateDirectories: true
        )
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "disposition": "PREPIXEL_DUPLICATE_FOUNDATION_REMOVED",
            "diagnosticOnly": true,
            "sourceAuthority": false,
            "productionSelected": false,
            "sourceDescriptor": sourceDescriptorPath,
            "sourceDescriptorFileSHA256": digest(sourceBytes),
            "outputDescriptor": outputDescriptorPath,
            "outputDescriptorFileSHA256": digest(outputBytes),
            "duplicateProof": [
                "canonicalFoundationBytesSHA256": digest(canonicalBytes),
                "duplicateFoundationBytesSHA256": digest(duplicateBytes),
                "canonicalBytesEqual": true,
                "dimensions": building["foundationDimensions"] as Any,
                "positionWorld": building["foundationPositionWorld"] as Any,
                "materialID": building["foundationMaterialID"] as Any,
            ],
            "removedMassBlock": duplicate,
            "massBlockCountBefore": massBlocks.count,
            "massBlockCountAfter": repairedMassBlocks.count,
            "onlyAuthorizedSemanticChange": true,
            "identityChanges": [
                "sourceRevision": [
                    "before": originalRoot["sourceRevision"] as Any,
                    "after": sourceRevision,
                ],
                "sampling.sourceRevisionBinding": [
                    "before": originalSampling["sourceRevisionBinding"] as Any,
                    "after": sourceRevision,
                ],
                "sceneGeometryID": [
                    "before": originalRoot["sceneGeometryID"] as Any,
                    "after": sceneGeometryID,
                ],
            ],
            "reconstructedCanonicalDescriptorIdentity": true,
            "expectedRenderedNodeCount": 51,
            "sceneKitMetalProcessCount": 0,
            "authoritativeRawProcessCount": 0,
            "normalizerProcessCount": 0,
        ]
        let reportBytes = try prettyData(report)
        try reportBytes.write(
            to: outputRoot.appendingPathComponent("PREPIXEL-VALIDATION.json"),
            options: .atomic
        )
        print("PASS duplicate foundations are canonical-byte equal")
        print("PASS v18 descriptor removes only v16-foundation")
        print(digest(outputBytes))
    }
}
