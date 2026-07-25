import Foundation

enum StructuralBoundaryError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: validate-structural-boundaries --repository-root <path> --scenes-root <path> --logical-building-id <id> --report <path>"
        case let .invalid(message):
            return message
        }
    }
}

struct StructuralPrimitive {
    let id: String
    let kind: String
    let xMin: Double
    let xMax: Double
    let yMin: Double
    let yMax: Double
    let zMin: Double
    let zMax: Double

    var record: [String: Any] {
        [
            "id": id,
            "kind": kind,
            "boundsWorld": [
                "x": [xMin, xMax],
                "y": [yMin, yMax],
                "z": [zMin, zMax],
            ],
        ]
    }
}

func requiredArgument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw StructuralBoundaryError.arguments
    }
    return arguments[index + 1]
}

func repositoryPath(
    _ url: URL,
    repositoryRoot: URL
) -> String {
    let prefix = repositoryRoot.path.hasSuffix("/")
        ? repositoryRoot.path
        : repositoryRoot.path + "/"
    guard url.path.hasPrefix(prefix) else {
        return url.path
    }
    return String(url.path.dropFirst(prefix.count))
}

func primitive(
    id: String,
    kind: String,
    dimensions: [Double],
    position: [Double]
) throws -> StructuralPrimitive {
    guard dimensions.count == 3, position.count == 3 else {
        throw StructuralBoundaryError.invalid(
            "\(id) requires three dimensions and position values"
        )
    }
    return StructuralPrimitive(
        id: id,
        kind: kind,
        xMin: position[0] - dimensions[0] / 2,
        xMax: position[0] + dimensions[0] / 2,
        yMin: position[1] - dimensions[1] / 2,
        yMax: position[1] + dimensions[1] / 2,
        zMin: position[2] - dimensions[2] / 2,
        zMax: position[2] + dimensions[2] / 2
    )
}

func overlapsFootprint(
    _ first: StructuralPrimitive,
    _ second: StructuralPrimitive,
    tolerance: Double
) -> Bool {
    min(first.xMax, second.xMax)
        - max(first.xMin, second.xMin) > tolerance
        && min(first.zMax, second.zMax)
            - max(first.zMin, second.zMin) > tolerance
}

@main
enum ValidateStructuralBoundariesMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let repositoryRoot = URL(
            fileURLWithPath: try requiredArgument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let scenesRoot = URL(
            fileURLWithPath: try requiredArgument(
                "--scenes-root",
                in: arguments
            )
        ).standardizedFileURL
        let logicalBuildingID = try requiredArgument(
            "--logical-building-id",
            in: arguments
        )
        let reportURL = URL(
            fileURLWithPath: try requiredArgument(
                "--report",
                in: arguments
            )
        ).standardizedFileURL
        let directions = ["north", "east", "south", "west"]
        let tolerance = 0.000_001
        let decoder = JSONDecoder()
        var directionRecords: [[String: Any]] = []
        var failures: [String] = []

        for direction in directions {
            let sceneURL = scenesRoot
                .appendingPathComponent(logicalBuildingID)
                .appendingPathComponent("variant-0")
                .appendingPathComponent(direction)
                .appendingPathComponent("scene.json")
            let descriptor = try decoder.decode(
                SceneDescriptor.self,
                from: Data(contentsOf: sceneURL)
            )
            var primitives: [StructuralPrimitive] = []
            for block in descriptor.building.massBlocks ?? [] {
                primitives.append(
                    try primitive(
                        id: block.id,
                        kind: "mass-block",
                        dimensions: block.dimensions,
                        position: block.positionWorld
                    )
                )
            }
            for roof in descriptor.building.roofVolumes ?? [] {
                primitives.append(
                    try primitive(
                        id: roof.id,
                        kind: "roof-envelope",
                        dimensions: roof.dimensions,
                        position: roof.positionWorld
                    )
                )
            }
            for band in descriptor.building.trimBands ?? [] {
                primitives.append(
                    try primitive(
                        id: band.id,
                        kind: "trim-band",
                        dimensions: band.dimensions,
                        position: band.positionWorld
                    )
                )
            }
            primitives.append(
                try primitive(
                    id: "chimney",
                    kind: "chimney",
                    dimensions: descriptor.building.chimney.dimensions,
                    position: descriptor.building.chimney.positionWorld
                )
            )
            for prop in descriptor.props {
                primitives.append(
                    try primitive(
                        id: prop.id,
                        kind: "prop",
                        dimensions: prop.dimensions,
                        position: prop.positionWorld
                    )
                )
            }

            var collisions: [[String: Any]] = []
            for firstIndex in primitives.indices {
                for secondIndex in primitives.indices
                    where secondIndex > firstIndex
                {
                    let first = primitives[firstIndex]
                    let second = primitives[secondIndex]
                    guard overlapsFootprint(
                        first,
                        second,
                        tolerance: tolerance
                    ) else {
                        continue
                    }
                    for firstBoundary in [first.yMin, first.yMax] {
                        for secondBoundary in [second.yMin, second.yMax]
                            where abs(firstBoundary - secondBoundary)
                                <= tolerance
                        {
                            collisions.append([
                                "firstID": first.id,
                                "secondID": second.id,
                                "sharedYWorld": firstBoundary,
                            ])
                        }
                    }
                }
            }
            if !collisions.isEmpty {
                failures.append(
                    "\(direction): \(collisions.count) coincident structural Y boundaries"
                )
            }
            directionRecords.append([
                "viewDirection": direction,
                "sceneFile": repositoryPath(
                    sceneURL,
                    repositoryRoot: repositoryRoot
                ),
                "sceneGeometryID": descriptor.sceneGeometryID,
                "sourceRevision": descriptor.sourceRevision,
                "primitiveCount": primitives.count,
                "primitives": primitives.map(\.record),
                "coincidentBoundaryCount": collisions.count,
                "coincidentBoundaries": collisions,
                "passed": collisions.isEmpty,
            ])
        }

        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "logicalBuildingID": logicalBuildingID,
            "purpose":
                "reject exact shared structural Y planes between overlapping authored volumes",
            "toleranceWorld": tolerance,
            "directions": directionRecords,
            "failures": failures,
            "passed": failures.isEmpty,
            "productionSelected": false,
        ]
        let reportData = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        var terminated = reportData
        terminated.append(0x0a)
        try FileManager.default.createDirectory(
            at: reportURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try terminated.write(to: reportURL, options: .atomic)
        if !failures.isEmpty {
            throw StructuralBoundaryError.invalid(
                failures.joined(separator: "\n")
            )
        }
    }
}
