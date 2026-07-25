import CryptoKit
import Foundation

enum QualityResetV10Error: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: advance-industrial-l2-quality-reset-v10 --repository-root <path>"
        case let .invalid(message):
            return message
        }
    }
}

private struct FoundationRepair {
    let dimensions: [Double]
    let position: [Double]
    let rationale: String
}

private let v09DescriptorHashes = [
    "north": "b810d67d2edb2603f3904fec2b7f50e3da61b61c2b289311ff0200fc6a6972bc",
    "east": "6dc6e6738049c4d50723e112c5118258e73186af408bc12e3e79fa80aa77f7fe",
    "south": "ff8c22a13434888720837a4157204636a4eca7da7f964292d51cf39e98232bd0",
    "west": "dbd7d71cbed6da5b149a81e3c70e9a27f1951999f6cd1c260d4b15d56c3f902a",
]

private let v09GeometryIDs = [
    "north": "industrial-l02-quality-reset-north-geometry-v01",
    "east": "industrial-l02-quality-reset-east-geometry-v01",
    "south": "industrial-l02-quality-reset-south-geometry-v01",
    "west": "industrial-l02-quality-reset-west-geometry-v01",
]

private let v10GeometryIDs = [
    "north": "industrial-l02-quality-reset-north-geometry-v02",
    "east": "industrial-l02-quality-reset-east-geometry-v02",
    "south": "industrial-l02-quality-reset-south-geometry-v02",
    "west": "industrial-l02-quality-reset-west-geometry-v02",
]

private let repairs = [
    "north": FoundationRepair(
        dimensions: [56, 3, 55],
        position: [0, 1.5, 0.5],
        rationale:
            "road-facing apron retains z=-28; ground-bearing slab reaches x=-28...28 and rear z=28 without sharing the apron road-face plane"
    ),
    "east": FoundationRepair(
        dimensions: [55, 3, 56],
        position: [-0.5, 1.5, 0],
        rationale:
            "road-facing apron retains x=28; ground-bearing slab reaches rear x=-28 and z=-28...28 without sharing the apron road-face plane"
    ),
    "south": FoundationRepair(
        dimensions: [56, 3, 55],
        position: [0, 1.5, -0.5],
        rationale:
            "road-facing apron retains z=28; ground-bearing slab reaches x=-28...28 and rear z=-28 without sharing the apron road-face plane"
    ),
    "west": FoundationRepair(
        dimensions: [55, 3, 56],
        position: [0.5, 1.5, 0],
        rationale:
            "road-facing apron retains x=-28; ground-bearing slab reaches rear x=28 and z=-28...28 without sharing the apron road-face plane"
    ),
]

private let materialLibraryHash =
    "27e4c199da63e9a3a4e8c0084caa8c4f375e7b16499dd7a7b507cdb384eeb8e1"

private func requiredArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw QualityResetV10Error.arguments
    }
    return arguments[index + 1]
}

private func hash(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func hash(_ url: URL) throws -> String {
    hash(try Data(contentsOf: url))
}

private func relative(
    _ url: URL,
    root: URL
) -> String {
    let prefix = root.path + "/"
    guard url.path.hasPrefix(prefix) else { return url.path }
    return String(url.path.dropFirst(prefix.count))
}

private func object(_ url: URL) throws -> [String: Any] {
    guard
        let value = try JSONSerialization.jsonObject(
            with: Data(contentsOf: url)
        ) as? [String: Any]
    else {
        throw QualityResetV10Error.invalid(
            "could not decode \(url.path)"
        )
    }
    return value
}

private func canonicalData(_ object: Any) throws -> Data {
    try JSONSerialization.data(
        withJSONObject: object,
        options: [.sortedKeys, .withoutEscapingSlashes]
    )
}

private func writeJSON(
    _ object: Any,
    to url: URL
) throws {
    var data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: url, options: .atomic)
}

private func immutablePayload(
    _ scene: [String: Any]
) throws -> [String: Any] {
    guard
        let building = scene["building"] as? [String: Any],
        let sampling = scene["sampling"] as? [String: Any]
    else {
        throw QualityResetV10Error.invalid(
            "scene lacks building or sampling"
        )
    }
    var immutableBuilding = building
    immutableBuilding.removeValue(forKey: "foundationDimensions")
    immutableBuilding.removeValue(forKey: "foundationPositionWorld")
    var immutableSampling = sampling
    immutableSampling.removeValue(forKey: "sourceRevisionBinding")
    var payload = scene
    payload.removeValue(forKey: "sourceRevision")
    payload.removeValue(forKey: "sceneGeometryID")
    payload["building"] = immutableBuilding
    payload["sampling"] = immutableSampling
    return payload
}

private func envelope(
    scene: [String: Any]
) throws -> [String: Any] {
    guard
        let building = scene["building"] as? [String: Any],
        let foundationDimensions =
            building["foundationDimensions"] as? [Double],
        let foundationPosition =
            building["foundationPositionWorld"] as? [Double],
        let massBlocks = building["massBlocks"] as? [[String: Any]],
        let props = scene["props"] as? [[String: Any]]
    else {
        throw QualityResetV10Error.invalid(
            "scene geometry arrays are malformed"
        )
    }
    var primitives = massBlocks + props
    primitives.append([
        "id": "foundation",
        "dimensions": foundationDimensions,
        "positionWorld": foundationPosition,
    ])
    var minimum = [
        Double.greatestFiniteMagnitude,
        Double.greatestFiniteMagnitude,
        Double.greatestFiniteMagnitude,
    ]
    var maximum = [
        -Double.greatestFiniteMagnitude,
        -Double.greatestFiniteMagnitude,
        -Double.greatestFiniteMagnitude,
    ]
    for primitive in primitives {
        guard
            let dimensions = primitive["dimensions"] as? [Double],
            let position = primitive["positionWorld"] as? [Double],
            dimensions.count == 3,
            position.count == 3
        else {
            throw QualityResetV10Error.invalid(
                "primitive bounds are malformed"
            )
        }
        for axis in 0..<3 {
            minimum[axis] = min(
                minimum[axis],
                position[axis] - dimensions[axis] / 2
            )
            maximum[axis] = max(
                maximum[axis],
                position[axis] + dimensions[axis] / 2
            )
        }
    }
    let passed =
        minimum[0] <= -28
        && maximum[0] >= 28
        && minimum[2] <= -28
        && maximum[2] >= 28
        && minimum[1] <= 0
        && maximum[1] >= 51
    return [
        "minimumWorld": minimum,
        "maximumWorld": maximum,
        "requiredHalfExtents": [28, 28],
        "minimumRequiredHeight": 51,
        "completeBuildingVolumePassed": passed,
    ]
}

@main
enum AdvanceIndustrialL2QualityResetV10Main {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try requiredArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let v09Root = repositoryRoot.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/source-authority/quality-reset-v01/scenes/industrial_l02/variant-0"
        )
        let v10Root = repositoryRoot.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/source-authority/quality-reset-v02/scenes/industrial_l02/variant-0"
        )
        let evidenceRoot = repositoryRoot.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/quality-reset-source-v10-prepixel-repair"
        )
        let materialURL = repositoryRoot.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/materials/industrial-l02-quality-reset-source-v09-materials.json"
        )
        guard try hash(materialURL) == materialLibraryHash else {
            throw QualityResetV10Error.invalid(
                "frozen material library hash drift"
            )
        }

        var records: [[String: Any]] = []
        var outputHashes = Set<String>()
        var outputGeometryIDs = Set<String>()
        for direction in ["north", "east", "south", "west"] {
            let v09URL = v09Root
                .appendingPathComponent(direction)
                .appendingPathComponent("scene.json")
            guard try hash(v09URL) == v09DescriptorHashes[direction] else {
                throw QualityResetV10Error.invalid(
                    "frozen \(direction) source-v09 hash drift"
                )
            }
            let v09 = try object(v09URL)
            guard
                v09["sourceRevision"] as? String == "source-v09",
                v09["sceneGeometryID"] as? String
                    == v09GeometryIDs[direction],
                var building = v09["building"] as? [String: Any],
                var sampling = v09["sampling"] as? [String: Any],
                let repair = repairs[direction]
            else {
                throw QualityResetV10Error.invalid(
                    "frozen \(direction) source-v09 identity mismatch"
                )
            }
            let beforePayloadHash = hash(
                try canonicalData(try immutablePayload(v09))
            )
            let beforeEnvelope = try envelope(scene: v09)

            building["foundationDimensions"] = repair.dimensions
            building["foundationPositionWorld"] = repair.position
            sampling["sourceRevisionBinding"] = "source-v10"
            var v10 = v09
            v10["sourceRevision"] = "source-v10"
            v10["sceneGeometryID"] = v10GeometryIDs[direction]
            v10["building"] = building
            v10["sampling"] = sampling

            let afterPayloadHash = hash(
                try canonicalData(try immutablePayload(v10))
            )
            guard beforePayloadHash == afterPayloadHash else {
                throw QualityResetV10Error.invalid(
                    "\(direction) mutation escaped the authorized foundation/revision fields"
                )
            }
            let afterEnvelope = try envelope(scene: v10)
            guard
                afterEnvelope["completeBuildingVolumePassed"] as? Bool
                    == true
            else {
                throw QualityResetV10Error.invalid(
                    "\(direction) repaired envelope still fails"
                )
            }
            let v10URL = v10Root
                .appendingPathComponent(direction)
                .appendingPathComponent("scene.json")
            try writeJSON(v10, to: v10URL)
            let outputHash = try hash(v10URL)
            guard
                outputHashes.insert(outputHash).inserted,
                outputGeometryIDs.insert(
                    v10GeometryIDs[direction]!
                ).inserted
            else {
                throw QualityResetV10Error.invalid(
                    "source-v10 direction identity collision"
                )
            }
            records.append([
                "direction": direction,
                "sourceV09File": relative(v09URL, root: repositoryRoot),
                "sourceV09SHA256": v09DescriptorHashes[direction]!,
                "sourceV09GeometryID": v09GeometryIDs[direction]!,
                "sourceV10File": relative(v10URL, root: repositoryRoot),
                "sourceV10SHA256": outputHash,
                "sourceV10GeometryID": v10GeometryIDs[direction]!,
                "unchangedPayloadSHA256": afterPayloadHash,
                "beforeEnvelope": beforeEnvelope,
                "afterEnvelope": afterEnvelope,
                "foundationRepair": [
                    "dimensions": repair.dimensions,
                    "positionWorld": repair.position,
                    "rationale": repair.rationale,
                ],
                "productionSelected": false,
            ])
        }

        try writeJSON(
            [
                "schema": 1,
                "task": "PLAY-027",
                "status": "pre-pixel-source-authority-repair-freeze",
                "sourceRevision": "source-v10",
                "rejectedSourceV09Preserved": true,
                "declaredFootprintWorld": [56, 56],
                "requiredHalfExtents": [28, 28],
                "records": records,
                "uniqueDescriptorHashes": outputHashes.count,
                "uniqueGeometryIDs": outputGeometryIDs.count,
                "materialLibrarySHA256": materialLibraryHash,
                "samplingAndAuthoredPayloadPreserved": true,
                "productionSelected": false,
                "passed": outputHashes.count == 4
                    && outputGeometryIDs.count == 4,
            ],
            to: evidenceRoot.appendingPathComponent(
                "GEOMETRY-REPAIR-FREEZE.json"
            )
        )
    }
}
