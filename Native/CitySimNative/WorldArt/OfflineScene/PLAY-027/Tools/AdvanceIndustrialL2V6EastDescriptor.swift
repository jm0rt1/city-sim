import CryptoKit
import Foundation

enum AdvanceIndustrialL2V6EastError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: advance-industrial-l2-v6-east-descriptor --repository-root <path> --fingerprint <json> --evidence-root <path>"
        case let .invalid(message):
            return message
        }
    }
}

private func argument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw AdvanceIndustrialL2V6EastError.arguments
    }
    return arguments[index + 1]
}

private func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func jsonData(_ object: Any) throws -> Data {
    var data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    return data
}

private func relative(_ url: URL, root: URL) -> String {
    let prefix = root.path + "/"
    return url.path.hasPrefix(prefix)
        ? String(url.path.dropFirst(prefix.count))
        : url.path
}

private func object(
    from data: Data,
    label: String
) throws -> [String: Any] {
    guard
        let object = try JSONSerialization.jsonObject(with: data)
            as? [String: Any]
    else {
        throw AdvanceIndustrialL2V6EastError.invalid(
            "\(label) is not a JSON object"
        )
    }
    return object
}

private func numbers(
    _ value: Any?,
    label: String
) throws -> [Double] {
    guard let numbers = value as? [NSNumber] else {
        throw AdvanceIndustrialL2V6EastError.invalid(
            "\(label) is not a numeric array"
        )
    }
    return numbers.map(\.doubleValue)
}

private func requireVector(
    _ value: Any?,
    equals expected: [Double],
    label: String
) throws {
    let actual = try numbers(value, label: label)
    guard actual == expected else {
        throw AdvanceIndustrialL2V6EastError.invalid(
            "\(label) changed: \(actual)"
        )
    }
}

private func strippedPreservationPayload(
    _ original: [String: Any]
) throws -> Data {
    var object = original
    object.removeValue(forKey: "sourceRevision")
    object.removeValue(forKey: "sceneGeometryID")
    object.removeValue(forKey: "toolchainFingerprint")
    if var sampling = object["sampling"] as? [String: Any] {
        sampling.removeValue(forKey: "sourceRevisionBinding")
        object["sampling"] = sampling
    }
    if var building = object["building"] as? [String: Any] {
        building.removeValue(forKey: "massBlocks")
        object["building"] = building
    }
    return try JSONSerialization.data(
        withJSONObject: object,
        options: [.sortedKeys, .withoutEscapingSlashes]
    )
}

@main
enum AdvanceIndustrialL2V6EastDescriptorMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try argument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let fingerprintURL = URL(
            fileURLWithPath: try argument(
                "--fingerprint",
                in: arguments
            )
        ).standardizedFileURL
        let evidenceRoot = URL(
            fileURLWithPath: try argument(
                "--evidence-root",
                in: arguments
            )
        ).standardizedFileURL
        let sceneRoot = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/scenes/industrial_l02/variant-0"
        )
        let eastURL = sceneRoot
            .appendingPathComponent("east/scene.json")
        let materialURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/materials/industrial-l02-v0-source-v05-materials.json"
        )
        let expectedSceneHashes = [
            "north":
                "f776d7486efd04766816019960f38b46119e46cf31b72c3f22ab48294d6452f5",
            "east":
                "aa4ec6dba5eb89c23c7e475f725a8181fc5954f1503cca4b5a700c399f565b44",
            "south":
                "5a40700a9b25574cc2886120932ae41e05a7210959ae6a9bd1a67072a1e4875a",
            "west":
                "7b7afb7eed54558f73a7e5123d67b2b13c8876114c6684b0314b260c0db10433",
        ]
        let expectedMaterialHash =
            "4f4e34aa87891d70c442e596315bcbd474f059638c0af69abe6ecaac17af0815"

        var preservedDirectionHashes: [String: String] = [:]
        for direction in ["north", "east", "south", "west"] {
            let url = sceneRoot
                .appendingPathComponent(direction)
                .appendingPathComponent("scene.json")
            let hash = digest(try Data(contentsOf: url))
            guard hash == expectedSceneHashes[direction] else {
                throw AdvanceIndustrialL2V6EastError.invalid(
                    "\(direction) source-v05 descriptor is not frozen authority"
                )
            }
            preservedDirectionHashes[direction] = hash
        }
        let materialData = try Data(contentsOf: materialURL)
        guard digest(materialData) == expectedMaterialHash else {
            throw AdvanceIndustrialL2V6EastError.invalid(
                "source-v05 material library changed"
            )
        }
        let fingerprintData = try Data(contentsOf: fingerprintURL)
        let fingerprintHash = digest(fingerprintData)
        let originalData = try Data(contentsOf: eastURL)
        var descriptor = try object(
            from: originalData,
            label: "Industrial L2 source-v05 East descriptor"
        )
        guard
            descriptor["sourceRevision"] as? String == "source-v05",
            descriptor["viewDirection"] as? String == "east",
            descriptor["productionSelected"] as? Bool == false,
            descriptor["sceneGeometryID"] as? String
                == "industrial-l02-v0-east-integrated-logistics-geometry-v3",
            var building = descriptor["building"] as? [String: Any],
            let originalMassBlocks = building["massBlocks"]
                as? [[String: Any]],
            var sampling = descriptor["sampling"] as? [String: Any],
            sampling["contractID"] as? String
                == "play027-deterministic-4x-no-msaa-lanczos-v3",
            sampling["sceneKitAntialiasing"] as? String == "none",
            sampling["sceneKitShadows"] as? String == "disabled",
            sampling["sceneKitLightingMode"] as? String
                == "authored-constant-v1"
        else {
            throw AdvanceIndustrialL2V6EastError.invalid(
                "Industrial L2 source-v05 East contract is incomplete"
            )
        }
        guard
            let hallIndex = originalMassBlocks.firstIndex(where: {
                $0["id"] as? String == "i02-east-high-assembly-hall"
            }),
            let tower = originalMassBlocks.first(where: {
                $0["id"] as? String == "i02-east-process-tower"
            }),
            originalMassBlocks.filter({
                ($0["id"] as? String)?
                    .hasPrefix("i02-east-high-assembly-hall") == true
            }).count == 1
        else {
            throw AdvanceIndustrialL2V6EastError.invalid(
                "frozen hall/tower mass ownership is not singular"
            )
        }
        let hall = originalMassBlocks[hallIndex]
        try requireVector(
            hall["dimensions"],
            equals: [38, 42, 38],
            label: "high assembly hall dimensions"
        )
        try requireVector(
            hall["positionWorld"],
            equals: [-6, 23, 6],
            label: "high assembly hall position"
        )
        guard
            hall["materialID"] as? String
                == "i02-v05-corrugated-northwest"
        else {
            throw AdvanceIndustrialL2V6EastError.invalid(
                "high assembly hall material changed"
            )
        }
        try requireVector(
            tower["dimensions"],
            equals: [16, 48, 14],
            label: "process tower dimensions"
        )
        try requireVector(
            tower["positionWorld"],
            equals: [-15, 26.5, 18],
            label: "process tower position"
        )
        guard
            tower["materialID"] as? String == "i02-v05-brick-northwest"
        else {
            throw AdvanceIndustrialL2V6EastError.invalid(
                "process tower material changed"
            )
        }

        let archiveURL = evidenceRoot
            .appendingPathComponent(
                "source-v05-descriptor/east-source-v05.json"
            )
        try FileManager.default.createDirectory(
            at: archiveURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: archiveURL.path) {
            guard try Data(contentsOf: archiveURL) == originalData else {
                throw AdvanceIndustrialL2V6EastError.invalid(
                    "source-v05 archive differs from frozen authority"
                )
            }
        } else {
            try originalData.write(to: archiveURL, options: .atomic)
        }

        let hallMaterial = "i02-v05-corrugated-northwest"
        let replacementBlocks: [[String: Any]] = [
            [
                "id": "i02-east-high-assembly-hall-left-strip",
                "dimensions": [2.0, 42.0, 38.0],
                "positionWorld": [-24.0, 23.0, 6.0],
                "materialID": hallMaterial,
            ],
            [
                "id": "i02-east-high-assembly-hall-right-strip",
                "dimensions": [20.0, 42.0, 38.0],
                "positionWorld": [3.0, 23.0, 6.0],
                "materialID": hallMaterial,
            ],
            [
                "id": "i02-east-high-assembly-hall-rear-block",
                "dimensions": [16.0, 42.0, 24.0],
                "positionWorld": [-15.0, 23.0, -1.0],
                "materialID": hallMaterial,
            ],
        ]
        var revisedMassBlocks = originalMassBlocks
        revisedMassBlocks.replaceSubrange(
            hallIndex...hallIndex,
            with: replacementBlocks
        )
        building["massBlocks"] = revisedMassBlocks
        descriptor["building"] = building
        descriptor["sourceRevision"] = "source-v06"
        descriptor["sceneGeometryID"] =
            "industrial-l02-v0-east-integrated-logistics-geometry-v4"
        sampling["sourceRevisionBinding"] = "source-v06"
        descriptor["sampling"] = sampling
        descriptor["toolchainFingerprint"] = [
            "role":
                "frozen-schema-2-v3-authored-constant-east-noncoplanar-offline-host-and-frameworks",
            "file": relative(fingerprintURL, root: root),
            "sha256": fingerprintHash,
        ]
        let revisedData = try jsonData(descriptor)
        let revisedObject = try object(
            from: revisedData,
            label: "Industrial L2 source-v06 East descriptor"
        )
        let originalPreservationHash = digest(
            try strippedPreservationPayload(
                try object(
                    from: originalData,
                    label: "source-v05 preservation payload"
                )
            )
        )
        let revisedPreservationHash = digest(
            try strippedPreservationPayload(revisedObject)
        )
        guard originalPreservationHash == revisedPreservationHash else {
            throw AdvanceIndustrialL2V6EastError.invalid(
                "unapproved descriptor payload changed"
            )
        }
        try revisedData.write(to: eastURL, options: .atomic)

        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "logicalBuildingID": "industrial_l02",
            "viewDirection": "east",
            "sourceRevision": "source-v06",
            "status": "PREPIXEL-ONLY",
            "sourceAuthority": false,
            "productionSelected": false,
            "sourceV05Descriptor": [
                "file": relative(archiveURL, root: root),
                "sha256": digest(originalData),
            ],
            "sourceV06Descriptor": [
                "file": relative(eastURL, root: root),
                "sha256": digest(revisedData),
            ],
            "sceneGeometryID":
                "industrial-l02-v0-east-integrated-logistics-geometry-v4",
            "toolchainFingerprint": [
                "file": relative(fingerprintURL, root: root),
                "sha256": fingerprintHash,
            ],
            "materialLibrary": [
                "file": relative(materialURL, root: root),
                "sha256": expectedMaterialHash,
            ],
            "preservationPayloadSHA256": originalPreservationHash,
            "preservedSourceV05DirectionHashes":
                preservedDirectionHashes,
            "topologyRepair": [
                "removed":
                    ["i02-east-high-assembly-hall"],
                "added": replacementBlocks,
                "processTowerUnchanged": tower,
                "externalUnionBoundsWorld": [
                    "x": [-25.0, 13.0],
                    "y": [2.0, 44.0],
                    "z": [-13.0, 25.0],
                ],
                "visiblePositiveZMaterialOwner":
                    "i02-east-process-tower",
            ],
            "changedDescriptorPaths": [
                "sourceRevision",
                "sceneGeometryID",
                "sampling.sourceRevisionBinding",
                "toolchainFingerprint",
                "building.massBlocks[source-v05-hall -> source-v06-left/right/rear]",
            ],
            "renderingAuthorizedByThisTool": false,
            "normalizationPerformed": false,
        ]
        let reportURL = evidenceRoot.appendingPathComponent(
            "SOURCE-V06-EAST-DESCRIPTOR-FREEZE.json"
        )
        try jsonData(report).write(to: reportURL, options: .atomic)
        print(
            "PASS Industrial L2 East source-v06 descriptor frozen: "
                + digest(revisedData)
        )
    }
}
