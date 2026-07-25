import CryptoKit
import Foundation

enum IndustrialL1V4Error: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: advance-industrial-l1-v4-descriptors --repository-root <path> --manifest <json>"
        case let .invalid(message):
            return message
        }
    }
}

func v4Argument(_ name: String, in arguments: [String]) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL1V4Error.arguments
    }
    return arguments[index + 1]
}

func v4SHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

func v4Relative(_ url: URL, root: URL) -> String {
    let prefix = root.path + "/"
    return url.path.hasPrefix(prefix)
        ? String(url.path.dropFirst(prefix.count))
        : url.path
}

func v4FarMassing(_ direction: String) throws -> (
    blocks: [[String: Any]],
    roofs: [[String: Any]],
    trims: [[String: Any]],
    clerestory: [[Double]]
) {
    switch direction {
    case "north":
        return (
            blocks: [
                ["id": "i01-north-west-hall-wing-v4", "dimensions": [17, 26, 42], "positionWorld": [-18.5, 15, 5], "materialID": "corrugated-steel-sage"],
                ["id": "i01-north-east-hall-wing-v4", "dimensions": [17, 26, 42], "positionWorld": [18.5, 15, 5], "materialID": "corrugated-steel-sage"],
                ["id": "i01-north-recessed-dock-house-v4", "dimensions": [20, 22, 12], "positionWorld": [0, 13.2, -22], "materialID": "brick-industrial-umber"],
            ],
            roofs: [
                ["id": "i01-north-roof-far-west-v4", "shape": "hip", "dimensions": [8, 9, 42], "positionWorld": [-23, 32.8, 5], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
                ["id": "i01-north-roof-inner-west-v4", "shape": "hip", "dimensions": [8, 9, 42], "positionWorld": [-14, 33.0, 5], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
                ["id": "i01-north-roof-inner-east-v4", "shape": "hip", "dimensions": [8, 9, 42], "positionWorld": [14, 33.0, 5], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
                ["id": "i01-north-roof-far-east-v4", "shape": "hip", "dimensions": [8, 9, 42], "positionWorld": [23, 33.2, 5], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
                ["id": "i01-north-dock-roof-v4", "shape": "flat-parapet", "dimensions": [20, 5, 12], "positionWorld": [0, 27, -22], "materialID": "roof-industrial-charcoal", "trimMaterialID": "hazard-yellow"],
            ],
            trims: [
                ["id": "i01-north-west-datum-v4", "dimensions": [18, 1.4, 43], "positionWorld": [-18.5, 9.3, 5], "materialID": "concrete-industrial-warm"],
                ["id": "i01-north-east-datum-v4", "dimensions": [18, 1.4, 43], "positionWorld": [18.5, 9.3, 5], "materialID": "concrete-industrial-warm"],
                ["id": "i01-north-dock-header-v4", "dimensions": [21, 1.2, 12.5], "positionWorld": [0, 23.1, -22], "materialID": "hazard-yellow"],
            ],
            clerestory: [[-5.5, 20.5, -27.2], [5.5, 20.5, -27.2]]
        )
    case "west":
        return (
            blocks: [
                ["id": "i01-west-north-hall-wing-v4", "dimensions": [42, 26, 17], "positionWorld": [5, 15, -18.5], "materialID": "corrugated-steel-sage"],
                ["id": "i01-west-south-hall-wing-v4", "dimensions": [42, 26, 17], "positionWorld": [5, 15, 18.5], "materialID": "corrugated-steel-sage"],
                ["id": "i01-west-recessed-dock-house-v4", "dimensions": [12, 22, 20], "positionWorld": [-22, 13.2, 0], "materialID": "brick-industrial-umber"],
            ],
            roofs: [
                ["id": "i01-west-roof-far-north-v4", "shape": "hip", "dimensions": [42, 9, 8], "positionWorld": [5, 32.8, -23], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
                ["id": "i01-west-roof-inner-north-v4", "shape": "hip", "dimensions": [42, 9, 8], "positionWorld": [5, 33.0, -14], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
                ["id": "i01-west-roof-inner-south-v4", "shape": "hip", "dimensions": [42, 9, 8], "positionWorld": [5, 33.0, 14], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
                ["id": "i01-west-roof-far-south-v4", "shape": "hip", "dimensions": [42, 9, 8], "positionWorld": [5, 33.2, 23], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
                ["id": "i01-west-dock-roof-v4", "shape": "flat-parapet", "dimensions": [12, 5, 20], "positionWorld": [-22, 27, 0], "materialID": "roof-industrial-charcoal", "trimMaterialID": "hazard-yellow"],
            ],
            trims: [
                ["id": "i01-west-north-datum-v4", "dimensions": [43, 1.4, 18], "positionWorld": [5, 9.3, -18.5], "materialID": "concrete-industrial-warm"],
                ["id": "i01-west-south-datum-v4", "dimensions": [43, 1.4, 18], "positionWorld": [5, 9.3, 18.5], "materialID": "concrete-industrial-warm"],
                ["id": "i01-west-dock-header-v4", "dimensions": [12.5, 1.2, 21], "positionWorld": [-22, 23.1, 0], "materialID": "hazard-yellow"],
            ],
            clerestory: [[-27.2, 20.5, 5.5], [-27.2, 20.5, -5.5]]
        )
    default:
        throw IndustrialL1V4Error.invalid(
            "\(direction) is not a far frontage"
        )
    }
}

@main
enum AdvanceIndustrialL1V4DescriptorsMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try v4Argument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let manifestURL = URL(
            fileURLWithPath: try v4Argument("--manifest", in: arguments)
        ).standardizedFileURL
        guard manifestURL.path.contains(
            "/docs/production/evidence/PLAY-027/"
        ) else {
            throw IndustrialL1V4Error.invalid(
                "manifest must remain under PLAY-027 evidence"
            )
        }
        let sceneRoot = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/scenes/industrial_l01/variant-0"
        )
        let archiveRoot = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l01/l01/source-v03-rejected/descriptors"
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
            let v3Data = try Data(contentsOf: sceneURL)
            guard
                var object = try JSONSerialization.jsonObject(
                    with: v3Data
                ) as? [String: Any],
                object["sourceRevision"] as? String == "source-v03",
                object["productionSelected"] as? Bool == false,
                var sampling = object["sampling"] as? [String: Any],
                var building = object["building"] as? [String: Any],
                var chimney = building["chimney"] as? [String: Any],
                var facades = object["facades"] as? [[String: Any]],
                let geometryID = object["sceneGeometryID"] as? String,
                geometryID.hasSuffix("geometry-v3")
            else {
                throw IndustrialL1V4Error.invalid(
                    "\(direction) is not frozen source-v03"
                )
            }
            try FileManager.default.createDirectory(
                at: archiveURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try v3Data.write(to: archiveURL, options: .atomic)

            object["sourceRevision"] = "source-v04"
            object["sceneGeometryID"] =
                String(geometryID.dropLast("geometry-v3".count))
                + "geometry-v4"
            sampling["sourceRevisionBinding"] = "source-v04"
            object["sampling"] = sampling
            chimney["dimensions"] = [4.5, 25, 4.5]
            var chimneyPosition =
                chimney["positionWorld"] as? [Double] ?? [0, 42.5, 0]
            chimneyPosition[1] = 42.5
            chimney["positionWorld"] = chimneyPosition
            building["chimney"] = chimney

            if direction == "north" || direction == "west" {
                let repair = try v4FarMassing(direction)
                building["massBlocks"] = repair.blocks
                building["roofVolumes"] = repair.roofs
                building["trimBands"] = repair.trims
                building["massingProfile"] =
                    "directional-loading-works-sightline-v4"
                guard
                    let targetIndex = facades.firstIndex(where: {
                        $0["direction"] as? String == direction
                    }),
                    var rhythms =
                        facades[targetIndex]["windowRhythms"]
                        as? [[String: Any]],
                    !rhythms.isEmpty
                else {
                    throw IndustrialL1V4Error.invalid(
                        "\(direction) target rhythm missing"
                    )
                }
                rhythms[0]["centersWorld"] = repair.clerestory
                rhythms[0]["id"] =
                    "\(direction)-dockhouse-clerestory-v4"
                facades[targetIndex]["windowRhythms"] = rhythms
            } else {
                building["massingProfile"] =
                    "directional-loading-works-sightline-v4"
            }
            object["building"] = building
            object["facades"] = facades

            var v4Data = try JSONSerialization.data(
                withJSONObject: object,
                options: [
                    .prettyPrinted,
                    .sortedKeys,
                    .withoutEscapingSlashes,
                ]
            )
            v4Data.append(0x0a)
            try v4Data.write(to: sceneURL, options: .atomic)
            let descriptorHash = v4SHA256(v4Data)
            let v4GeometryID = object["sceneGeometryID"] as! String
            guard descriptorHashes.insert(descriptorHash).inserted else {
                throw IndustrialL1V4Error.invalid(
                    "\(direction) aliases a sibling descriptor"
                )
            }
            guard geometryIDs.insert(v4GeometryID).inserted else {
                throw IndustrialL1V4Error.invalid(
                    "\(direction) aliases a sibling geometry ID"
                )
            }
            samples.append([
                "direction": direction,
                "archivedSourceV03File": v4Relative(
                    archiveURL,
                    root: root
                ),
                "archivedSourceV03SHA256": v4SHA256(v3Data),
                "sourceV04DescriptorFile": v4Relative(
                    sceneURL,
                    root: root
                ),
                "sourceV04DescriptorSHA256": descriptorHash,
                "sceneGeometryID": v4GeometryID,
                "orientationTransform": "none",
                "productionSelected": false,
            ])
        }
        let manifest: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "logicalBuildingID": "industrial_l01",
            "sourceRevision": "source-v04",
            "repair":
                "authored split-hall sightlines expose centered far-edge loading bays; common exhaust envelope restores raw bounds",
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
