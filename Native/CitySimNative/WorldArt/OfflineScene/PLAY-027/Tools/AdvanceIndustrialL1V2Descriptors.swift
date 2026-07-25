import CryptoKit
import Foundation

enum AdvanceIndustrialL1V2Error: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: advance-industrial-l1-v2-descriptors --repository-root <path> --manifest <json>"
        case let .invalid(message):
            return message
        }
    }
}

func industrialV2Argument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw AdvanceIndustrialL1V2Error.arguments
    }
    return arguments[index + 1]
}

func industrialV2SHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

func industrialV2Relative(
    _ url: URL,
    repositoryRoot: URL
) -> String {
    let prefix = repositoryRoot.path + "/"
    return url.path.hasPrefix(prefix)
        ? String(url.path.dropFirst(prefix.count))
        : url.path
}

@main
enum AdvanceIndustrialL1V2DescriptorsMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try industrialV2Argument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let manifestURL = URL(
            fileURLWithPath: try industrialV2Argument(
                "--manifest",
                in: arguments
            )
        ).standardizedFileURL
        guard manifestURL.path.contains(
            "/docs/production/evidence/PLAY-027/"
        ) else {
            throw AdvanceIndustrialL1V2Error.invalid(
                "manifest must remain under PLAY-027 evidence"
            )
        }
        let sceneRoot = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/scenes/industrial_l01/variant-0"
        )
        let archiveRoot = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l01/l01/source-v01-rejected/descriptors"
        )
        let directions = ["north", "east", "south", "west"]
        var samples: [[String: Any]] = []
        var descriptorHashes = Set<String>()
        var geometryIDs = Set<String>()

        for direction in directions {
            let sceneURL = sceneRoot
                .appendingPathComponent(direction)
                .appendingPathComponent("scene.json")
            let archiveURL = archiveRoot
                .appendingPathComponent(direction)
                .appendingPathComponent("scene.json")
            let sourceV1Data = try Data(contentsOf: sceneURL)
            guard
                var object = try JSONSerialization.jsonObject(
                    with: sourceV1Data
                ) as? [String: Any],
                (object["schema"] as? NSNumber)?.intValue == 2,
                object["sourceRevision"] as? String == "source-v01",
                object["logicalBuildingID"] as? String == "industrial_l01",
                object["viewDirection"] as? String == direction,
                object["authoredIndependently"] as? Bool == true,
                object["productionSelected"] as? Bool == false,
                var derivation = object["derivation"] as? [String: Any],
                derivation["siblingSource"] is NSNull,
                derivation["mirror"] as? Bool == false,
                (derivation["rotationDegrees"] as? NSNumber)?.doubleValue == 0,
                derivation["transform"] as? String == "none",
                let geometryID = object["sceneGeometryID"] as? String,
                geometryID.hasSuffix("geometry-v1"),
                var sampling = object["sampling"] as? [String: Any],
                sampling["contractID"] as? String
                    == "play027-deterministic-4x-no-msaa-lanczos-v3",
                sampling["sourceRevisionBinding"] as? String == "source-v01",
                sampling["purpose"] as? String == "source-authority",
                var entrance = object["entrance"] as? [String: Any],
                entrance["style"] as? String == "loading-bay"
            else {
                throw AdvanceIndustrialL1V2Error.invalid(
                    "\(direction) is not frozen Industrial source-v01"
                )
            }
            try FileManager.default.createDirectory(
                at: archiveURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try sourceV1Data.write(to: archiveURL, options: .atomic)

            object["sourceRevision"] = "source-v02"
            object["sceneGeometryID"] =
                String(geometryID.dropLast("geometry-v1".count))
                + "geometry-v2"
            sampling["sourceRevisionBinding"] = "source-v02"
            object["sampling"] = sampling
            if direction == "west" {
                entrance["porchLateralOffset"] = 10
            }
            object["entrance"] = entrance
            derivation["sourceKind"] = "independent-scene-description"
            object["derivation"] = derivation

            var sourceV2Data = try JSONSerialization.data(
                withJSONObject: object,
                options: [
                    .prettyPrinted,
                    .sortedKeys,
                    .withoutEscapingSlashes,
                ]
            )
            sourceV2Data.append(0x0a)
            try sourceV2Data.write(to: sceneURL, options: .atomic)
            let descriptorHash = industrialV2SHA256(sourceV2Data)
            let sourceV2GeometryID = object["sceneGeometryID"] as! String
            guard descriptorHashes.insert(descriptorHash).inserted else {
                throw AdvanceIndustrialL1V2Error.invalid(
                    "\(direction) aliases a sibling descriptor"
                )
            }
            guard geometryIDs.insert(sourceV2GeometryID).inserted else {
                throw AdvanceIndustrialL1V2Error.invalid(
                    "\(direction) aliases a sibling geometry ID"
                )
            }
            samples.append([
                "direction": direction,
                "archivedSourceV01File": industrialV2Relative(
                    archiveURL,
                    repositoryRoot: root
                ),
                "archivedSourceV01SHA256":
                    industrialV2SHA256(sourceV1Data),
                "sourceV02DescriptorFile": industrialV2Relative(
                    sceneURL,
                    repositoryRoot: root
                ),
                "sourceV02DescriptorSHA256": descriptorHash,
                "sceneGeometryID": sourceV2GeometryID,
                "sourceRevision": "source-v02",
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
            "sourceRevision": "source-v02",
            "repair":
                "grounded full-scale loading-bay returns for far-frontage north and west visibility",
            "contractID":
                "play027-deterministic-4x-no-msaa-lanczos-v3",
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
