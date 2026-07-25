import Foundation

enum IndustrialL1V5ValidationError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: validate-industrial-l1-v5-frontages --repository-root <path> --scenes-root <path> --report <json>"
        case let .invalid(message):
            return message
        }
    }
}

func v5RequiredArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL1V5ValidationError.arguments
    }
    return arguments[index + 1]
}

func v5RepositoryPath(_ url: URL, root: URL) -> String {
    let prefix = root.path + "/"
    return url.path.hasPrefix(prefix)
        ? String(url.path.dropFirst(prefix.count))
        : url.path
}

func v5ApproximatelyEqual(
    _ first: [Double],
    _ second: [Double],
    tolerance: Double = 0.000_001
) -> Bool {
    first.count == second.count
        && zip(first, second).allSatisfy {
            abs($0 - $1) <= tolerance
        }
}

@main
enum ValidateIndustrialL1V5FrontagesMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try v5RequiredArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let scenesRoot = URL(
            fileURLWithPath: try v5RequiredArgument(
                "--scenes-root",
                in: arguments
            )
        ).standardizedFileURL
        let reportURL = URL(
            fileURLWithPath: try v5RequiredArgument(
                "--report",
                in: arguments
            )
        ).standardizedFileURL
        let expectedBases: [String: [Double]] = [
            "north": [0, 2, -28],
            "east": [28, 2, 0],
            "south": [0, 2, 28],
            "west": [-28, 2, 0],
        ]
        let expectedAprons: [String: ([Double], [Double])] = [
            "north": ([26, 0.8, 18], [0, 2.65, -23]),
            "east": ([18, 0.8, 26], [23, 2.65, 0]),
            "south": ([26, 0.8, 18], [0, 2.65, 23]),
            "west": ([18, 0.8, 26], [-23, 2.65, 0]),
        ]
        let expectedHeaders: [String: ([Double], [Double])] = [
            "north": ([30, 4, 4], [0, 56, -25]),
            "east": ([4, 4, 30], [25, 56, 0]),
            "south": ([30, 4, 4], [0, 56, 25]),
            "west": ([4, 4, 30], [-25, 56, 0]),
        ]
        let directions = ["north", "east", "south", "west"]
        let decoder = JSONDecoder()
        var directionRecords: [[String: Any]] = []
        var failures: [String] = []

        for direction in directions {
            let sceneURL = scenesRoot
                .appendingPathComponent("industrial_l01")
                .appendingPathComponent("variant-0")
                .appendingPathComponent(direction)
                .appendingPathComponent("scene.json")
            let descriptor = try decoder.decode(
                SceneDescriptor.self,
                from: Data(contentsOf: sceneURL)
            )
            var itemFailures: [String] = []
            let prefix = "i01-\(direction)-frontage"
            let masses = descriptor.building.massBlocks ?? []
            let trims = descriptor.building.trimBands ?? []
            let posts = masses.filter {
                $0.id.hasPrefix(prefix) && $0.id.contains("gantry-post")
            }
            let apron = masses.first {
                $0.id == "\(prefix)-service-apron-v5"
            }
            let header = trims.first {
                $0.id == "\(prefix)-gantry-header-v5"
            }
            let crown = trims.first {
                $0.id == "\(prefix)-hazard-crown-v5"
            }
            let stripe = trims.first {
                $0.id == "\(prefix)-apron-stripe-v5"
            }

            if descriptor.sourceRevision != "source-v05" {
                itemFailures.append("source revision is not source-v05")
            }
            if descriptor.logicalBuildingID != "industrial_l01"
                || descriptor.family != "industrial"
                || descriptor.level != 1
            {
                itemFailures.append("industrial L1 identity drift")
            }
            if descriptor.viewDirection != direction {
                itemFailures.append("view direction drift")
            }
            if !descriptor.authoredIndependently
                || descriptor.derivation.siblingSource != nil
                || descriptor.derivation.mirror
                || descriptor.derivation.rotationDegrees != 0
                || descriptor.derivation.transform != "none"
            {
                itemFailures.append("sibling derivation or transform present")
            }
            if descriptor.productionSelected {
                itemFailures.append("productionSelected must remain false")
            }
            if descriptor.registration.orientationTransform != "none" {
                itemFailures.append("registration transform is not none")
            }
            if descriptor.entrance.style != "loading-bay"
                || descriptor.entrance.porchLateralOffset != 0
                || !v5ApproximatelyEqual(
                    descriptor.entrance.baseWorld,
                    expectedBases[direction]!
                )
            {
                itemFailures.append(
                    "loading entrance is not centered on the frozen socket"
                )
            }
            if descriptor.sampling?.contractID
                != "play027-deterministic-4x-no-msaa-lanczos-v3"
                || descriptor.sampling?.sourceRevisionBinding
                    != "source-v05"
            {
                itemFailures.append("schema-2 v3 sampling binding drift")
            }
            if posts.count != 2
                || posts.contains(where: {
                    !v5ApproximatelyEqual($0.dimensions, [2.8, 55, 2.8])
                        || abs($0.positionWorld[1] - 28.5) > 0.000_001
                })
            {
                itemFailures.append("two grounded full-height posts missing")
            }
            if let apron, let expected = expectedAprons[direction] {
                if !v5ApproximatelyEqual(apron.dimensions, expected.0)
                    || !v5ApproximatelyEqual(
                        apron.positionWorld,
                        expected.1
                    )
                {
                    itemFailures.append(
                        "service apron does not cross the frozen socket"
                    )
                }
            } else {
                itemFailures.append("service apron missing")
            }
            if let header, let expected = expectedHeaders[direction] {
                if !v5ApproximatelyEqual(header.dimensions, expected.0)
                    || !v5ApproximatelyEqual(
                        header.positionWorld,
                        expected.1
                    )
                {
                    itemFailures.append(
                        "gantry header is not direction-authored"
                    )
                }
            } else {
                itemFailures.append("gantry header missing")
            }
            if crown == nil || stripe == nil {
                itemFailures.append(
                    "hazard crown or socket-apron stripe missing"
                )
            }
            if let crown {
                let top =
                    crown.positionWorld[1] + crown.dimensions[1] / 2
                if top < 59.8 {
                    itemFailures.append(
                        "frontage crown does not clear vertical envelope"
                    )
                }
            }
            failures.append(
                contentsOf: itemFailures.map { "\(direction): \($0)" }
            )
            directionRecords.append([
                "viewDirection": direction,
                "sceneFile": v5RepositoryPath(sceneURL, root: root),
                "sceneGeometryID": descriptor.sceneGeometryID,
                "entranceBaseWorld": descriptor.entrance.baseWorld,
                "gantryPostIDs": posts.map(\.id).sorted(),
                "gantryHeaderID": header?.id ?? NSNull(),
                "hazardCrownID": crown?.id ?? NSNull(),
                "serviceApronID": apron?.id ?? NSNull(),
                "apronStripeID": stripe?.id ?? NSNull(),
                "failures": itemFailures,
                "passed": itemFailures.isEmpty,
            ])
        }
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "logicalBuildingID": "industrial_l01",
            "sourceRevision": "source-v05",
            "purpose":
                "prove independently authored socket-connected loading throat, gantry, hazard crown, and service apron geometry",
            "directions": directionRecords,
            "failures": failures,
            "passed": failures.isEmpty,
            "productionSelected": false,
        ]
        var data = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        data.append(0x0a)
        try FileManager.default.createDirectory(
            at: reportURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: reportURL, options: .atomic)
        if !failures.isEmpty {
            throw IndustrialL1V5ValidationError.invalid(
                failures.joined(separator: "\n")
            )
        }
    }
}
