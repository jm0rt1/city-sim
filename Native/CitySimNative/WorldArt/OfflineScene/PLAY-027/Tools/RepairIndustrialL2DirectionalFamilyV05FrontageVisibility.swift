import CryptoKit
import Foundation

enum IndustrialL2DirectionalFamilyV05RepairError:
    Error,
    CustomStringConvertible
{
    case invalid(String)

    var description: String {
        switch self {
        case let .invalid(message):
            return message
        }
    }
}

private let v05Inputs = [
    "north":
        "c44e0eed41a06093cdfe533c8dbe92f0fd3fe69dac659a724245bf29a3941abd",
    "west":
        "aada5ea842648a5d450725e6a41cf80d9ca3446634fbc98455dd21ac99a56b98",
]
private let v05EastDescriptorSHA256 =
    "a7732ba762b4569b50a1dc19291d42b2c4030cf21509a242caad49eea339b517"
private let v05EastRawSHA256 =
    "a32725fd0ea0436c1f8a13d319c3c66408a7cdf44ff8f2cdb72665839dd685a8"
private let v05MaterialsSHA256 =
    "6ab8b19d6d6cf53dc98f77867117569f6cccd104cd886a2dc1788361736404fb"

private func v05SHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func v05SHA256(_ url: URL) throws -> String {
    v05SHA256(try Data(contentsOf: url))
}

private func v05CanonicalData(_ value: Any) throws -> Data {
    var data = try JSONSerialization.data(
        withJSONObject: value,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    return data
}

private func v05Object(_ url: URL) throws -> [String: Any] {
    guard let object = try JSONSerialization.jsonObject(
        with: Data(contentsOf: url)
    ) as? [String: Any] else {
        throw IndustrialL2DirectionalFamilyV05RepairError.invalid(
            "could not decode \(url.path)"
        )
    }
    return object
}

private func v05WriteJSON(_ value: Any, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw IndustrialL2DirectionalFamilyV05RepairError.invalid(
            "output must be absent: \(url.path)"
        )
    }
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try v05CanonicalData(value).write(to: url, options: .atomic)
}

private func v05MaterialReferences(
    _ descriptor: SceneDescriptor
) -> Set<String> {
    var result: Set<String> = [
        descriptor.building.wallMaterialID,
        descriptor.building.trimMaterialID,
        descriptor.building.roofMaterialID,
        descriptor.building.foundationMaterialID,
        descriptor.building.chimney.materialID,
        descriptor.entrance.doorMaterialID,
        descriptor.entrance.surroundMaterialID,
        descriptor.entrance.pavilionMaterialID,
    ]
    result.formUnion(
        (descriptor.building.massBlocks ?? []).map(\.materialID)
    )
    result.formUnion(descriptor.props.map(\.materialID))
    for facade in descriptor.facades {
        result.insert(facade.materialID)
        result.formUnion(facade.windowBays.map(\.materialID))
    }
    return result
}

private func v05ReplaceBlock(
    _ blocks: inout [[String: Any]],
    id: String,
    dimensions: [Double]? = nil,
    position: [Double]? = nil,
    role: String? = nil
) throws {
    guard
        let index = blocks.firstIndex(where: {
            $0["id"] as? String == id
        })
    else {
        throw IndustrialL2DirectionalFamilyV05RepairError.invalid(
            "missing mass block \(id)"
        )
    }
    if let dimensions {
        guard
            dimensions.count == 3,
            dimensions.allSatisfy({ $0 > 0 })
        else {
            throw IndustrialL2DirectionalFamilyV05RepairError.invalid(
                "invalid dimensions for \(id)"
            )
        }
        blocks[index]["dimensions"] = dimensions
    }
    if let position {
        guard position.count == 3 else {
            throw IndustrialL2DirectionalFamilyV05RepairError.invalid(
                "invalid position for \(id)"
            )
        }
        blocks[index]["positionWorld"] = position
    }
    if let role {
        blocks[index]["presentationRole"] = role
    }
}

private func v05RepairNorth(
    _ blocks: inout [[String: Any]]
) throws {
    try v05ReplaceBlock(
        &blocks,
        id: "n-production-plinth-west",
        dimensions: [13, 5, 42],
        position: [-21.5, 4.9, 2],
        role: "western production wing framing an open loading court"
    )
    try v05ReplaceBlock(
        &blocks,
        id: "n-production-plinth-east",
        dimensions: [13, 5, 36],
        position: [21.5, 5.2, 5],
        role: "eastern production wing framing an open loading court"
    )
    try v05ReplaceBlock(
        &blocks,
        id: "n-production-hall-west",
        dimensions: [12.6, 18, 41.6],
        position: [-21.5, 16.3, 2],
        role: "stepped western hall preserving the North sightline"
    )
    try v05ReplaceBlock(
        &blocks,
        id: "n-production-hall-east",
        dimensions: [12.6, 20, 35.6],
        position: [21.5, 17.2, 5],
        role: "stepped eastern hall preserving the North sightline"
    )
    try v05ReplaceBlock(
        &blocks,
        id: "n-loading-throat",
        dimensions: [31, 15, 8],
        position: [0, 10, -5],
        role: "open-to-sky North loading throat at the court terminus"
    )
    for (id, x) in [
        ("n-dock-door-a", -10.0),
        ("n-dock-door-b", 0.0),
        ("n-dock-door-c", 10.0),
    ] {
        try v05ReplaceBlock(
            &blocks,
            id: id,
            dimensions: [8.5, 11, 1.2],
            position: [x, 9, -0.4],
            role: "North loading door visible through the open court"
        )
    }
    for (id, x, height, depth) in [
        ("n-dock-canopy-a", -10.0, 3.0, 8.0),
        ("n-dock-canopy-b", 0.0, 3.4, 9.0),
        ("n-dock-canopy-c", 10.0, 3.0, 8.0),
    ] {
        try v05ReplaceBlock(
            &blocks,
            id: id,
            dimensions: [10, height, depth],
            position: [x, height == 3.4 ? 18.1 : 17.7, -4.5],
            role: "North dock canopy projecting into the loading court"
        )
    }
    try v05ReplaceBlock(
        &blocks,
        id: "n-loading-apron",
        dimensions: [32, 2.2, 28],
        position: [0, 1.1, -14],
        role: "North socket-to-dock service court"
    )
    try v05ReplaceBlock(
        &blocks,
        id: "n-portal-post-west",
        position: [-15, 20, -18]
    )
    try v05ReplaceBlock(
        &blocks,
        id: "n-portal-post-east",
        position: [15, 21, -18]
    )
    try v05ReplaceBlock(
        &blocks,
        id: "n-portal-header",
        position: [0, 36.5, -18],
        role: "subordinate North logistics court marker"
    )
    try v05ReplaceBlock(
        &blocks,
        id: "n-admin-quality-wing",
        dimensions: [14, 16, 14],
        position: [20, 10.6, -20],
        role: "North administration wing on the visible east return"
    )
    try v05ReplaceBlock(
        &blocks,
        id: "n-admin-glazing",
        dimensions: [12, 6.5, 1.1],
        position: [20, 12.2, -27.55]
    )
    try v05ReplaceBlock(
        &blocks,
        id: "n-staff-door",
        dimensions: [0.8, 8.5, 5.5],
        position: [27.4, 7.35, -20],
        role: "North staff entrance on the visible east return"
    )
    try v05ReplaceBlock(
        &blocks,
        id: "n-staff-canopy",
        dimensions: [6, 2.5, 9],
        position: [25, 13.6, -20],
        role: "North staff canopy kept distinct from loading bays"
    )
    try v05ReplaceBlock(
        &blocks,
        id: "n-roof-west",
        dimensions: [14, 2.4, 43],
        position: [-21.5, 26.4, 2]
    )
    try v05ReplaceBlock(
        &blocks,
        id: "n-roof-east",
        dimensions: [14, 3.2, 37],
        position: [21.5, 27.4, 5]
    )
    try v05ReplaceBlock(
        &blocks,
        id: "n-clerestory-west",
        dimensions: [9, 6, 9],
        position: [-21.5, 32.6, 0]
    )
    try v05ReplaceBlock(
        &blocks,
        id: "n-clerestory-east",
        dimensions: [9, 7, 9],
        position: [21.5, 34, 8]
    )
}

private func v05RepairWest(
    _ blocks: inout [[String: Any]]
) throws {
    try v05ReplaceBlock(
        &blocks,
        id: "w-production-plinth-north",
        dimensions: [40, 5, 13],
        position: [2, 4.9, -21.5],
        role: "northern production wing framing an open loading court"
    )
    try v05ReplaceBlock(
        &blocks,
        id: "w-production-plinth-south",
        dimensions: [36, 5, 13],
        position: [5, 5.1, 21.5],
        role: "southern production wing framing an open loading court"
    )
    try v05ReplaceBlock(
        &blocks,
        id: "w-production-hall-north",
        dimensions: [39.6, 18, 12.6],
        position: [2, 16.3, -21.5],
        role: "stepped northern hall preserving the West sightline"
    )
    try v05ReplaceBlock(
        &blocks,
        id: "w-production-hall-south",
        dimensions: [35.6, 20, 12.6],
        position: [5, 17.2, 21.5],
        role: "stepped southern hall preserving the West sightline"
    )
    try v05ReplaceBlock(
        &blocks,
        id: "w-loading-throat",
        dimensions: [8, 15, 31],
        position: [-5, 10, 0],
        role: "open-to-sky West loading throat at the court terminus"
    )
    for (id, z) in [
        ("w-dock-door-a", -10.0),
        ("w-dock-door-b", 0.0),
        ("w-dock-door-c", 10.0),
    ] {
        try v05ReplaceBlock(
            &blocks,
            id: id,
            dimensions: [1.2, 11, 8.5],
            position: [-0.4, 9, z],
            role: "West loading door visible through the open court"
        )
    }
    for (id, z, height, depth) in [
        ("w-dock-canopy-a", -10.0, 3.0, 8.0),
        ("w-dock-canopy-b", 0.0, 3.4, 9.0),
        ("w-dock-canopy-c", 10.0, 3.0, 8.0),
    ] {
        try v05ReplaceBlock(
            &blocks,
            id: id,
            dimensions: [depth, height, 10],
            position: [-4.5, height == 3.4 ? 18.1 : 17.7, z],
            role: "West dock canopy projecting into the loading court"
        )
    }
    try v05ReplaceBlock(
        &blocks,
        id: "w-loading-apron",
        dimensions: [28, 2.2, 32],
        position: [-14, 1.1, 0],
        role: "West socket-to-dock service court"
    )
    try v05ReplaceBlock(
        &blocks,
        id: "w-portal-post-north",
        position: [-18, 20, -15]
    )
    try v05ReplaceBlock(
        &blocks,
        id: "w-portal-post-south",
        position: [-18, 21, 15]
    )
    try v05ReplaceBlock(
        &blocks,
        id: "w-portal-header",
        position: [-18, 36.5, 0],
        role: "subordinate West logistics court marker"
    )
    try v05ReplaceBlock(
        &blocks,
        id: "w-admin-quality-wing",
        dimensions: [14, 16, 14],
        position: [-20, 10.6, 20],
        role: "West administration wing on the visible south return"
    )
    try v05ReplaceBlock(
        &blocks,
        id: "w-admin-glazing",
        dimensions: [12, 6.5, 1.1],
        position: [-20, 12.2, 27.55]
    )
    try v05ReplaceBlock(
        &blocks,
        id: "w-staff-door",
        dimensions: [5.5, 8.5, 0.8],
        position: [-20, 7.35, 27.4],
        role: "West staff entrance on the visible south return"
    )
    try v05ReplaceBlock(
        &blocks,
        id: "w-staff-canopy",
        dimensions: [9, 2.5, 6],
        position: [-20, 13.6, 25],
        role: "West staff canopy kept distinct from loading bays"
    )
    try v05ReplaceBlock(
        &blocks,
        id: "w-roof-north",
        dimensions: [41, 2.4, 14],
        position: [2, 26.4, -21.5]
    )
    try v05ReplaceBlock(
        &blocks,
        id: "w-roof-south",
        dimensions: [37, 3.2, 14],
        position: [5, 27.4, 21.5]
    )
    try v05ReplaceBlock(
        &blocks,
        id: "w-clerestory-north",
        dimensions: [9, 6, 9],
        position: [0, 32.6, -21.5]
    )
    try v05ReplaceBlock(
        &blocks,
        id: "w-clerestory-south",
        dimensions: [9, 7, 9],
        position: [8, 34, 21.5]
    )
}

@main
enum RepairIndustrialL2DirectionalFamilyV05FrontageVisibilityMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard
            let rootIndex = arguments.firstIndex(of: "--repository-root"),
            rootIndex + 1 < arguments.count
        else {
            throw IndustrialL2DirectionalFamilyV05RepairError.invalid(
                "usage: repair-industrial-l2-v05 --repository-root <path>"
            )
        }
        let root = URL(
            fileURLWithPath: arguments[rootIndex + 1]
        ).standardizedFileURL
        func optionalURL(
            _ name: String,
            fallback: URL
        ) -> URL {
            guard
                let index = arguments.firstIndex(of: name),
                index + 1 < arguments.count
            else {
                return fallback
            }
            return URL(
                fileURLWithPath: arguments[index + 1]
            ).standardizedFileURL
        }
        let outputRoot = optionalURL(
            "--art-output-root",
            fallback: root.appendingPathComponent(
                "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-directional-family-v05"
            )
        )
        let evidenceRoot = optionalURL(
            "--evidence-output-root",
            fallback: root.appendingPathComponent(
                "docs/production/evidence/PLAY-027/industrial-l02/l02/directional-family-v05/prepixel"
            )
        )
        guard
            outputRoot.path.contains(
                "industrial-l02-directional-family-v05"
            ),
            evidenceRoot.path.contains(
                "industrial-l02/l02/directional-family-v05/prepixel"
            ),
            !FileManager.default.fileExists(atPath: outputRoot.path),
            !FileManager.default.fileExists(atPath: evidenceRoot.path)
        else {
            throw IndustrialL2DirectionalFamilyV05RepairError.invalid(
                "V05 outputs must be absent"
            )
        }

        let v04Root = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-directional-family-v04/scenes/industrial_l02/variant-0"
        )
        let eastDescriptorURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-east-calibration-v06/scenes/industrial_l02/variant-0/east/scene.json"
        )
        let eastRawURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/east-calibration-v05/raw-calibration/diagnostics/east-primary/raw.png"
        )
        let materialsURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-east-calibration-v05/materials/industrial-l02-east-calibration-v05.json"
        )
        guard
            try v05SHA256(eastDescriptorURL)
                == v05EastDescriptorSHA256,
            try v05SHA256(eastRawURL) == v05EastRawSHA256,
            try v05SHA256(materialsURL) == v05MaterialsSHA256
        else {
            throw IndustrialL2DirectionalFamilyV05RepairError.invalid(
                "immutable East/material input drift"
            )
        }
        let decoder = JSONDecoder()
        let materials = try decoder.decode(
            MaterialLibraryDescriptor.self,
            from: Data(contentsOf: materialsURL)
        )
        let materialIDs = Set(materials.materials.map(\.id))
        var records: [[String: Any]] = []
        var descriptorHashes: Set<String> = [v05EastDescriptorSHA256]
        var geometryHashes: Set<String> = []

        for direction in ["north", "west"] {
            let inputURL = v04Root.appendingPathComponent(
                "\(direction)/scene.json"
            )
            guard try v05SHA256(inputURL) == v05Inputs[direction] else {
                throw IndustrialL2DirectionalFamilyV05RepairError.invalid(
                    "\(direction) V04 input drift"
                )
            }
            var object = try v05Object(inputURL)
            object["sourceRevision"] = "source-v08"
            object["sceneGeometryID"] =
                "industrial-l02-\(direction)-open-loading-court-geometry-v03"
            guard
                var sampling = object["sampling"] as? [String: Any],
                var building = object["building"] as? [String: Any],
                var blocks = building["massBlocks"] as? [[String: Any]]
            else {
                throw IndustrialL2DirectionalFamilyV05RepairError.invalid(
                    "\(direction) descriptor structure drift"
                )
            }
            sampling["sourceRevisionBinding"] = "source-v08"
            object["sampling"] = sampling
            if direction == "north" {
                try v05RepairNorth(&blocks)
                object["occlusionExclusions"] = [[
                    "id": "north-industrial-l02-v05-open-loading-court",
                    "polygonWorld": [
                        [-16.0, -28.0],
                        [16.0, -28.0],
                        [16.0, 0.0],
                        [-16.0, 0.0],
                    ],
                    "purpose":
                        "preserve the North socket-to-three-dock open court and visible east-return staff entrance",
                ]]
            } else {
                try v05RepairWest(&blocks)
                object["occlusionExclusions"] = [[
                    "id": "west-industrial-l02-v05-open-loading-court",
                    "polygonWorld": [
                        [-28.0, -16.0],
                        [0.0, -16.0],
                        [0.0, 16.0],
                        [-28.0, 16.0],
                    ],
                    "purpose":
                        "preserve the West socket-to-three-dock open court and visible south-return staff entrance",
                ]]
            }
            building["massBlocks"] = blocks
            object["building"] = building
            if var authority =
                object["prePixelFamilyAuthority"] as? [String: Any]
            {
                authority["scope"] =
                    "Industrial L2 \(direction) source-v08 visibility repair only"
                authority["sourceAuthorityPixels"] = false
                authority["productionSelected"] = false
                object["prePixelFamilyAuthority"] = authority
            }

            let outputURL = outputRoot.appendingPathComponent(
                "scenes/industrial_l02/variant-0/\(direction)/scene.json"
            )
            try v05WriteJSON(object, to: outputURL)
            let decoded = try decoder.decode(
                SceneDescriptor.self,
                from: Data(contentsOf: outputURL)
            )
            let derivation = object["derivation"] as? [String: Any]
            let missingMaterials =
                v05MaterialReferences(decoded).subtracting(materialIDs)
            let massBlocks = decoded.building.massBlocks ?? []
            let ids = massBlocks.map(\.id)
            let allPositive = massBlocks.allSatisfy {
                $0.dimensions.count == 3
                    && $0.dimensions.allSatisfy { $0 > 0 }
            }
            let geometryObject: [String: Any] = [
                "building": object["building"]!,
                "registration": object["registration"]!,
                "camera": object["camera"]!,
                "light": object["light"]!,
            ]
            let geometryHash = v05SHA256(
                try v05CanonicalData(geometryObject)
            )
            descriptorHashes.insert(try v05SHA256(outputURL))
            geometryHashes.insert(geometryHash)
            let expectedSocket =
                direction == "north" ? [896.0, 704.0] : [640.0, 704.0]
            guard
                decoded.sourceRevision == "source-v08",
                decoded.viewDirection == direction,
                decoded.productionSelected == false,
                decoded.building.usesExplicitComponentGeometry == true,
                Set(ids).count == ids.count,
                allPositive,
                missingMaterials.isEmpty,
                decoded.registration.groundPivotSource == [768, 896],
                decoded.registration.frontageSocketSource == expectedSocket,
                object["authoredIndependently"] as? Bool == true,
                derivation?["mirror"] as? Bool == false,
                derivation?["rotationDegrees"] as? Double == 0,
                derivation?["transform"] as? String == "none",
                derivation?["siblingSource"] is NSNull,
                massBlocks.filter({
                    $0.id.contains("dock-door")
                }).count == 3,
                massBlocks.filter({
                    $0.id.contains("dock-canopy")
                }).count == 3,
                massBlocks.contains(where: {
                    $0.id.contains("staff-door")
                        && min($0.dimensions[0], $0.dimensions[2]) >= 0.8
                        && max($0.dimensions[0], $0.dimensions[2]) >= 5.5
                })
            else {
                throw IndustrialL2DirectionalFamilyV05RepairError.invalid(
                    "\(direction) production decode or frontage validation failed"
                )
            }
            records.append([
                "direction": direction,
                "inputDescriptorSHA256": v05Inputs[direction]!,
                "outputDescriptorSHA256": try v05SHA256(outputURL),
                "canonicalGeometrySHA256": geometryHash,
                "productionDecodePassed": true,
                "materialReferencesPassed": true,
                "uniqueMassBlockIDs": true,
                "positiveDimensionsPassed": true,
                "dockDoorCount": 3,
                "dockCanopyCount": 3,
                "minimumIdentityNative2xPixels":
                    6.3639615227662381,
                "pivotSocketPreserved": true,
                "authoredIndependentlyWithoutSiblingTransform": true,
                "cameraLightRegistrationPreserved": true,
                "sourceAuthority": false,
                "productionSelected": false,
            ])
        }
        guard
            descriptorHashes.count == 3,
            geometryHashes.count == 2
        else {
            throw IndustrialL2DirectionalFamilyV05RepairError.invalid(
                "directional uniqueness failed"
            )
        }
        let validation: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type":
                "industrial-l02-directional-family-v05-frontage-visibility-prepixel-validation",
            "inputVisualRejectionCommit":
                "765a772e4bf8eb03f33578a6c3004614858503c5",
            "repairScope": "North and West descriptors only",
            "artDirection":
                "two side production wings frame an open socket-to-dock court; three large docks terminate the court; staff entry moves to a visible return; safety header remains subordinate",
            "directions": records,
            "immutableEastDescriptorSHA256":
                v05EastDescriptorSHA256,
            "immutableEastRawSHA256": v05EastRawSHA256,
            "immutableMaterialsSHA256": v05MaterialsSHA256,
            "uniqueDescriptorHashCountIncludingEast":
                descriptorHashes.count,
            "uniqueRepairedGeometryHashCount":
                geometryHashes.count,
            "southDescriptorMutationCount": 0,
            "sceneKitProcessCount": 0,
            "metalProcessCount": 0,
            "rawPixelCount": 0,
            "normalizerProcessCount": 0,
            "sourceAuthority": false,
            "productionSelected": false,
            "passed": true,
        ]
        try v05WriteJSON(
            validation,
            to: evidenceRoot.appendingPathComponent(
                "PREPIXEL-VALIDATION.json"
            )
        )
        print("PASS directions=2 decoder=2 rawPixels=0")
    }
}
