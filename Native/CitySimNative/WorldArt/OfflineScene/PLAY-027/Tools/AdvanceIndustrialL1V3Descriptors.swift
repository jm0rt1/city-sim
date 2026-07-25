import CryptoKit
import Foundation

enum AdvanceIndustrialL1V3Error: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: advance-industrial-l1-v3-descriptors --repository-root <path> --manifest <json>"
        case let .invalid(message):
            return message
        }
    }
}

func industrialV3Argument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw AdvanceIndustrialL1V3Error.arguments
    }
    return arguments[index + 1]
}

func industrialV3SHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

func industrialV3Relative(
    _ url: URL,
    repositoryRoot: URL
) -> String {
    let prefix = repositoryRoot.path + "/"
    return url.path.hasPrefix(prefix)
        ? String(url.path.dropFirst(prefix.count))
        : url.path
}

func industrialV3Building(_ direction: String) throws -> [String: Any] {
    let mainBlock: [String: Any]
    let dockBlock: [String: Any]
    let mainRoofs: [[String: Any]]
    let dockRoof: [String: Any]
    let trimBands: [[String: Any]]
    let chimneyPosition: [Double]

    switch direction {
    case "north":
        mainBlock = ["id": "i01-north-setback-hall", "dimensions": [52, 26, 42], "positionWorld": [0, 15, 5], "materialID": "corrugated-steel-sage"]
        dockBlock = ["id": "i01-north-dock-house", "dimensions": [32, 22, 12], "positionWorld": [0, 13.2, -22], "materialID": "brick-industrial-umber"]
        mainRoofs = [
            ["id": "i01-north-roof-west", "shape": "hip", "dimensions": [17, 9, 42], "positionWorld": [-17.5, 32.8, 5], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
            ["id": "i01-north-roof-center", "shape": "hip", "dimensions": [17, 9, 42], "positionWorld": [0, 33.0, 5], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
            ["id": "i01-north-roof-east", "shape": "hip", "dimensions": [17, 9, 42], "positionWorld": [17.5, 33.2, 5], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
        ]
        dockRoof = ["id": "i01-north-dock-roof", "shape": "flat-parapet", "dimensions": [32, 5, 12], "positionWorld": [0, 27.0, -22], "materialID": "roof-industrial-charcoal", "trimMaterialID": "hazard-yellow"]
        trimBands = [
            ["id": "i01-north-main-datum", "dimensions": [53, 1.4, 43], "positionWorld": [0, 9.3, 5], "materialID": "concrete-industrial-warm"],
            ["id": "i01-north-dock-header", "dimensions": [33, 1.2, 12.5], "positionWorld": [0, 23.1, -22], "materialID": "hazard-yellow"],
        ]
        chimneyPosition = [-19, 39.5, 14]
    case "east":
        mainBlock = ["id": "i01-east-setback-hall", "dimensions": [42, 26, 52], "positionWorld": [-5, 15, 0], "materialID": "corrugated-steel-sage"]
        dockBlock = ["id": "i01-east-dock-house", "dimensions": [12, 22, 32], "positionWorld": [22, 13.2, 0], "materialID": "brick-industrial-umber"]
        mainRoofs = [
            ["id": "i01-east-roof-north", "shape": "hip", "dimensions": [42, 9, 17], "positionWorld": [-5, 32.8, -17.5], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
            ["id": "i01-east-roof-center", "shape": "hip", "dimensions": [42, 9, 17], "positionWorld": [-5, 33.0, 0], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
            ["id": "i01-east-roof-south", "shape": "hip", "dimensions": [42, 9, 17], "positionWorld": [-5, 33.2, 17.5], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
        ]
        dockRoof = ["id": "i01-east-dock-roof", "shape": "flat-parapet", "dimensions": [12, 5, 32], "positionWorld": [22, 27.0, 0], "materialID": "roof-industrial-charcoal", "trimMaterialID": "hazard-yellow"]
        trimBands = [
            ["id": "i01-east-main-datum", "dimensions": [43, 1.4, 53], "positionWorld": [-5, 9.3, 0], "materialID": "concrete-industrial-warm"],
            ["id": "i01-east-dock-header", "dimensions": [12.5, 1.2, 33], "positionWorld": [22, 23.1, 0], "materialID": "hazard-yellow"],
        ]
        chimneyPosition = [-14, 39.5, -18]
    case "south":
        mainBlock = ["id": "i01-south-setback-hall", "dimensions": [52, 26, 42], "positionWorld": [0, 15, -5], "materialID": "corrugated-steel-sage"]
        dockBlock = ["id": "i01-south-dock-house", "dimensions": [32, 22, 12], "positionWorld": [0, 13.2, 22], "materialID": "brick-industrial-umber"]
        mainRoofs = [
            ["id": "i01-south-roof-west", "shape": "hip", "dimensions": [17, 9, 42], "positionWorld": [-17.5, 32.8, -5], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
            ["id": "i01-south-roof-center", "shape": "hip", "dimensions": [17, 9, 42], "positionWorld": [0, 33.0, -5], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
            ["id": "i01-south-roof-east", "shape": "hip", "dimensions": [17, 9, 42], "positionWorld": [17.5, 33.2, -5], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
        ]
        dockRoof = ["id": "i01-south-dock-roof", "shape": "flat-parapet", "dimensions": [32, 5, 12], "positionWorld": [0, 27.0, 22], "materialID": "roof-industrial-charcoal", "trimMaterialID": "hazard-yellow"]
        trimBands = [
            ["id": "i01-south-main-datum", "dimensions": [53, 1.4, 43], "positionWorld": [0, 9.3, -5], "materialID": "concrete-industrial-warm"],
            ["id": "i01-south-dock-header", "dimensions": [33, 1.2, 12.5], "positionWorld": [0, 23.1, 22], "materialID": "hazard-yellow"],
        ]
        chimneyPosition = [19, 39.5, -14]
    case "west":
        mainBlock = ["id": "i01-west-setback-hall", "dimensions": [42, 26, 52], "positionWorld": [5, 15, 0], "materialID": "corrugated-steel-sage"]
        dockBlock = ["id": "i01-west-dock-house", "dimensions": [12, 22, 32], "positionWorld": [-22, 13.2, 0], "materialID": "brick-industrial-umber"]
        mainRoofs = [
            ["id": "i01-west-roof-north", "shape": "hip", "dimensions": [42, 9, 17], "positionWorld": [5, 32.8, -17.5], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
            ["id": "i01-west-roof-center", "shape": "hip", "dimensions": [42, 9, 17], "positionWorld": [5, 33.0, 0], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
            ["id": "i01-west-roof-south", "shape": "hip", "dimensions": [42, 9, 17], "positionWorld": [5, 33.2, 17.5], "materialID": "roof-industrial-charcoal", "trimMaterialID": "concrete-industrial-warm"],
        ]
        dockRoof = ["id": "i01-west-dock-roof", "shape": "flat-parapet", "dimensions": [12, 5, 32], "positionWorld": [-22, 27.0, 0], "materialID": "roof-industrial-charcoal", "trimMaterialID": "hazard-yellow"]
        trimBands = [
            ["id": "i01-west-main-datum", "dimensions": [43, 1.4, 53], "positionWorld": [5, 9.3, 0], "materialID": "concrete-industrial-warm"],
            ["id": "i01-west-dock-header", "dimensions": [12.5, 1.2, 33], "positionWorld": [-22, 23.1, 0], "materialID": "hazard-yellow"],
        ]
        chimneyPosition = [14, 39.5, 18]
    default:
        throw AdvanceIndustrialL1V3Error.invalid(
            "invalid direction \(direction)"
        )
    }
    return [
        "width": 56,
        "depth": 56,
        "foundationHeight": 2,
        "floorHeight": 14,
        "floors": 2,
        "wallHeight": 28,
        "roofHeight": 10,
        "roofOverhang": 1,
        "wallMaterialID": "corrugated-steel-sage",
        "trimMaterialID": "concrete-industrial-warm",
        "roofMaterialID": "roof-industrial-charcoal",
        "foundationMaterialID": "concrete-industrial-warm",
        "chimney": [
            "positionWorld": chimneyPosition,
            "dimensions": [4.5, 19, 4.5],
            "materialID": "chimney-metal",
        ],
        "massingProfile": "directional-setback-high-bay-loading-works",
        "usesLegacyDomesticDetails": false,
        "massBlocks": [mainBlock, dockBlock],
        "roofVolumes": mainRoofs + [dockRoof],
        "trimBands": trimBands,
    ]
}

func industrialV3TargetCenters(_ direction: String) throws -> [[Double]] {
    switch direction {
    case "north":
        return [[-10, 20.5, -27.2], [10, 20.5, -27.2]]
    case "east":
        return [[27.2, 20.5, -10], [27.2, 20.5, 10]]
    case "south":
        return [[10, 20.5, 27.2], [-10, 20.5, 27.2]]
    case "west":
        return [[-27.2, 20.5, 10], [-27.2, 20.5, -10]]
    default:
        throw AdvanceIndustrialL1V3Error.invalid(
            "invalid direction \(direction)"
        )
    }
}

@main
enum AdvanceIndustrialL1V3DescriptorsMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try industrialV3Argument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let manifestURL = URL(
            fileURLWithPath: try industrialV3Argument(
                "--manifest",
                in: arguments
            )
        ).standardizedFileURL
        guard manifestURL.path.contains(
            "/docs/production/evidence/PLAY-027/"
        ) else {
            throw AdvanceIndustrialL1V3Error.invalid(
                "manifest must remain under PLAY-027 evidence"
            )
        }
        let sceneRoot = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/scenes/industrial_l01/variant-0"
        )
        let archiveRoot = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l01/l01/source-v02-rejected/descriptors"
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
            let sourceV2Data = try Data(contentsOf: sceneURL)
            guard
                var object = try JSONSerialization.jsonObject(
                    with: sourceV2Data
                ) as? [String: Any],
                object["sourceRevision"] as? String == "source-v02",
                object["logicalBuildingID"] as? String == "industrial_l01",
                object["viewDirection"] as? String == direction,
                object["productionSelected"] as? Bool == false,
                let geometryID = object["sceneGeometryID"] as? String,
                geometryID.hasSuffix("geometry-v2"),
                var sampling = object["sampling"] as? [String: Any],
                sampling["contractID"] as? String
                    == "play027-deterministic-4x-no-msaa-lanczos-v3",
                var entrance = object["entrance"] as? [String: Any],
                var facades = object["facades"] as? [[String: Any]]
            else {
                throw AdvanceIndustrialL1V3Error.invalid(
                    "\(direction) is not frozen Industrial source-v02"
                )
            }
            try FileManager.default.createDirectory(
                at: archiveURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try sourceV2Data.write(to: archiveURL, options: .atomic)

            object["sourceRevision"] = "source-v03"
            object["sceneGeometryID"] =
                String(geometryID.dropLast("geometry-v2".count))
                + "geometry-v3"
            sampling["sourceRevisionBinding"] = "source-v03"
            object["sampling"] = sampling
            entrance["porchLateralOffset"] =
                (direction == "north" || direction == "west") ? 10 : 0
            object["entrance"] = entrance
            object["building"] = try industrialV3Building(direction)

            guard
                let targetIndex = facades.firstIndex(where: {
                    $0["direction"] as? String == direction
                }),
                var rhythms =
                    facades[targetIndex]["windowRhythms"]
                    as? [[String: Any]],
                !rhythms.isEmpty
            else {
                throw AdvanceIndustrialL1V3Error.invalid(
                    "\(direction) target facade rhythm missing"
                )
            }
            rhythms[0]["centersWorld"] =
                try industrialV3TargetCenters(direction)
            rhythms[0]["id"] = "\(direction)-dockhouse-clerestory-v3"
            facades[targetIndex]["windowRhythms"] = rhythms
            object["facades"] = facades

            var sourceV3Data = try JSONSerialization.data(
                withJSONObject: object,
                options: [
                    .prettyPrinted,
                    .sortedKeys,
                    .withoutEscapingSlashes,
                ]
            )
            sourceV3Data.append(0x0a)
            try sourceV3Data.write(to: sceneURL, options: .atomic)
            let descriptorHash = industrialV3SHA256(sourceV3Data)
            let sourceV3GeometryID = object["sceneGeometryID"] as! String
            guard descriptorHashes.insert(descriptorHash).inserted else {
                throw AdvanceIndustrialL1V3Error.invalid(
                    "\(direction) aliases a sibling descriptor"
                )
            }
            guard geometryIDs.insert(sourceV3GeometryID).inserted else {
                throw AdvanceIndustrialL1V3Error.invalid(
                    "\(direction) aliases a sibling geometry ID"
                )
            }
            samples.append([
                "direction": direction,
                "archivedSourceV02File": industrialV3Relative(
                    archiveURL,
                    repositoryRoot: root
                ),
                "archivedSourceV02SHA256":
                    industrialV3SHA256(sourceV2Data),
                "sourceV03DescriptorFile": industrialV3Relative(
                    sceneURL,
                    repositoryRoot: root
                ),
                "sourceV03DescriptorSHA256": descriptorHash,
                "sceneGeometryID": sourceV3GeometryID,
                "sourceRevision": "source-v03",
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
            "sourceRevision": "source-v03",
            "repair":
                "four explicit setback halls and grounded dock houses replace renderer-created corner returns",
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
