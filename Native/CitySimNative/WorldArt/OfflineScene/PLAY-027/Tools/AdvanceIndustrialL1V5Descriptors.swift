import CryptoKit
import Foundation

enum IndustrialL1V5Error: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: advance-industrial-l1-v5-descriptors --repository-root <path> --manifest <json>"
        case let .invalid(message):
            return message
        }
    }
}

func v5Argument(_ name: String, in arguments: [String]) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL1V5Error.arguments
    }
    return arguments[index + 1]
}

func v5SHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

func v5Relative(_ url: URL, root: URL) -> String {
    let prefix = root.path + "/"
    return url.path.hasPrefix(prefix)
        ? String(url.path.dropFirst(prefix.count))
        : url.path
}

func v5FrontageGeometry(
    _ direction: String
) throws -> (
    masses: [[String: Any]],
    trims: [[String: Any]]
) {
    let prefix = "i01-\(direction)-frontage"
    switch direction {
    case "north":
        return (
            masses: [
                ["id": "\(prefix)-west-gantry-post-v5", "dimensions": [2.8, 55, 2.8], "positionWorld": [-13, 28.5, -25], "materialID": "chimney-metal"],
                ["id": "\(prefix)-east-gantry-post-v5", "dimensions": [2.8, 55, 2.8], "positionWorld": [13, 28.5, -25], "materialID": "chimney-metal"],
                ["id": "\(prefix)-service-apron-v5", "dimensions": [26, 0.8, 18], "positionWorld": [0, 2.65, -23], "materialID": "concrete-industrial-warm"],
            ],
            trims: [
                ["id": "\(prefix)-gantry-header-v5", "dimensions": [30, 4, 4], "positionWorld": [0, 56, -25], "materialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-hazard-crown-v5", "dimensions": [26, 1.6, 4.6], "positionWorld": [0, 59, -25], "materialID": "hazard-yellow"],
                ["id": "\(prefix)-apron-stripe-v5", "dimensions": [18, 0.35, 3], "positionWorld": [0, 3, -29], "materialID": "hazard-yellow"],
            ]
        )
    case "east":
        return (
            masses: [
                ["id": "\(prefix)-north-gantry-post-v5", "dimensions": [2.8, 55, 2.8], "positionWorld": [25, 28.5, -13], "materialID": "chimney-metal"],
                ["id": "\(prefix)-south-gantry-post-v5", "dimensions": [2.8, 55, 2.8], "positionWorld": [25, 28.5, 13], "materialID": "chimney-metal"],
                ["id": "\(prefix)-service-apron-v5", "dimensions": [18, 0.8, 26], "positionWorld": [23, 2.65, 0], "materialID": "concrete-industrial-warm"],
            ],
            trims: [
                ["id": "\(prefix)-gantry-header-v5", "dimensions": [4, 4, 30], "positionWorld": [25, 56, 0], "materialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-hazard-crown-v5", "dimensions": [4.6, 1.6, 26], "positionWorld": [25, 59, 0], "materialID": "hazard-yellow"],
                ["id": "\(prefix)-apron-stripe-v5", "dimensions": [3, 0.35, 18], "positionWorld": [29, 3, 0], "materialID": "hazard-yellow"],
            ]
        )
    case "south":
        return (
            masses: [
                ["id": "\(prefix)-east-gantry-post-v5", "dimensions": [2.8, 55, 2.8], "positionWorld": [13, 28.5, 25], "materialID": "chimney-metal"],
                ["id": "\(prefix)-west-gantry-post-v5", "dimensions": [2.8, 55, 2.8], "positionWorld": [-13, 28.5, 25], "materialID": "chimney-metal"],
                ["id": "\(prefix)-service-apron-v5", "dimensions": [26, 0.8, 18], "positionWorld": [0, 2.65, 23], "materialID": "concrete-industrial-warm"],
            ],
            trims: [
                ["id": "\(prefix)-gantry-header-v5", "dimensions": [30, 4, 4], "positionWorld": [0, 56, 25], "materialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-hazard-crown-v5", "dimensions": [26, 1.6, 4.6], "positionWorld": [0, 59, 25], "materialID": "hazard-yellow"],
                ["id": "\(prefix)-apron-stripe-v5", "dimensions": [18, 0.35, 3], "positionWorld": [0, 3, 29], "materialID": "hazard-yellow"],
            ]
        )
    case "west":
        return (
            masses: [
                ["id": "\(prefix)-south-gantry-post-v5", "dimensions": [2.8, 55, 2.8], "positionWorld": [-25, 28.5, 13], "materialID": "chimney-metal"],
                ["id": "\(prefix)-north-gantry-post-v5", "dimensions": [2.8, 55, 2.8], "positionWorld": [-25, 28.5, -13], "materialID": "chimney-metal"],
                ["id": "\(prefix)-service-apron-v5", "dimensions": [18, 0.8, 26], "positionWorld": [-23, 2.65, 0], "materialID": "concrete-industrial-warm"],
            ],
            trims: [
                ["id": "\(prefix)-gantry-header-v5", "dimensions": [4, 4, 30], "positionWorld": [-25, 56, 0], "materialID": "concrete-industrial-warm"],
                ["id": "\(prefix)-hazard-crown-v5", "dimensions": [4.6, 1.6, 26], "positionWorld": [-25, 59, 0], "materialID": "hazard-yellow"],
                ["id": "\(prefix)-apron-stripe-v5", "dimensions": [3, 0.35, 18], "positionWorld": [-29, 3, 0], "materialID": "hazard-yellow"],
            ]
        )
    default:
        throw IndustrialL1V5Error.invalid("invalid direction \(direction)")
    }
}

@main
enum AdvanceIndustrialL1V5DescriptorsMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try v5Argument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let manifestURL = URL(
            fileURLWithPath: try v5Argument("--manifest", in: arguments)
        ).standardizedFileURL
        guard manifestURL.path.contains(
            "/docs/production/evidence/PLAY-027/"
        ) else {
            throw IndustrialL1V5Error.invalid(
                "manifest must remain under PLAY-027 evidence"
            )
        }
        let sceneRoot = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/scenes/industrial_l01/variant-0"
        )
        let archiveRoot = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l01/l01/source-v04-rejected/descriptors"
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
            let v4Data = try Data(contentsOf: sceneURL)
            guard
                var object = try JSONSerialization.jsonObject(
                    with: v4Data
                ) as? [String: Any],
                object["sourceRevision"] as? String == "source-v04",
                object["viewDirection"] as? String == direction,
                object["productionSelected"] as? Bool == false,
                var sampling = object["sampling"] as? [String: Any],
                var building = object["building"] as? [String: Any],
                var entrance = object["entrance"] as? [String: Any],
                var masses = building["massBlocks"] as? [[String: Any]],
                var trims = building["trimBands"] as? [[String: Any]],
                let geometryID = object["sceneGeometryID"] as? String,
                geometryID.hasSuffix("geometry-v4")
            else {
                throw IndustrialL1V5Error.invalid(
                    "\(direction) is not frozen source-v04"
                )
            }
            try FileManager.default.createDirectory(
                at: archiveURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try v4Data.write(to: archiveURL, options: .atomic)

            let frontage = try v5FrontageGeometry(direction)
            masses.append(contentsOf: frontage.masses)
            trims.append(contentsOf: frontage.trims)
            building["massBlocks"] = masses
            building["trimBands"] = trims
            building["massingProfile"] =
                "directional-loading-throat-gantry-v5"
            entrance["porchLateralOffset"] = 0
            object["building"] = building
            object["entrance"] = entrance
            object["sourceRevision"] = "source-v05"
            object["sceneGeometryID"] =
                String(geometryID.dropLast("geometry-v4".count))
                + "geometry-v5"
            sampling["sourceRevisionBinding"] = "source-v05"
            object["sampling"] = sampling

            var v5Data = try JSONSerialization.data(
                withJSONObject: object,
                options: [
                    .prettyPrinted,
                    .sortedKeys,
                    .withoutEscapingSlashes,
                ]
            )
            v5Data.append(0x0a)
            try v5Data.write(to: sceneURL, options: .atomic)
            let descriptorHash = v5SHA256(v5Data)
            let v5GeometryID = object["sceneGeometryID"] as! String
            guard descriptorHashes.insert(descriptorHash).inserted else {
                throw IndustrialL1V5Error.invalid(
                    "\(direction) aliases a sibling descriptor"
                )
            }
            guard geometryIDs.insert(v5GeometryID).inserted else {
                throw IndustrialL1V5Error.invalid(
                    "\(direction) aliases a sibling geometry ID"
                )
            }
            samples.append([
                "direction": direction,
                "archivedSourceV04File": v5Relative(
                    archiveURL,
                    root: root
                ),
                "archivedSourceV04SHA256": v5SHA256(v4Data),
                "sourceV05DescriptorFile": v5Relative(
                    sceneURL,
                    root: root
                ),
                "sourceV05DescriptorSHA256": descriptorHash,
                "sceneGeometryID": v5GeometryID,
                "orientationTransform": "none",
                "productionSelected": false,
            ])
        }
        let manifest: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "logicalBuildingID": "industrial_l01",
            "sourceRevision": "source-v05",
            "repair":
                "four authored loading-throat gantries, elevated hazard crowns, and socket-crossing service aprons",
            "contractID":
                "play027-deterministic-4x-no-msaa-lanczos-v3",
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
