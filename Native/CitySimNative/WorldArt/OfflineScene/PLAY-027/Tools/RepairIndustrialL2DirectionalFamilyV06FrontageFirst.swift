import CryptoKit
import Foundation

enum IndustrialL2V06RepairError: Error, CustomStringConvertible {
    case invalid(String)

    var description: String {
        switch self {
        case let .invalid(message):
            return message
        }
    }
}

private let v06InputHashes = [
    "north":
        "4b980d5f02fd8bb1bd7f8ef2f734c17387e4c42845723430be318ad96be9e852",
    "west":
        "912ebc29cc1a5c3241d89a94e62dc0ecfbf053317c99fbfe1884781ca8eb49dc",
]
private let v06EastDescriptorSHA256 =
    "a7732ba762b4569b50a1dc19291d42b2c4030cf21509a242caad49eea339b517"
private let v06EastRawSHA256 =
    "a32725fd0ea0436c1f8a13d319c3c66408a7cdf44ff8f2cdb72665839dd685a8"
private let v06MaterialsSHA256 =
    "6ab8b19d6d6cf53dc98f77867117569f6cccd104cd886a2dc1788361736404fb"
private let v06RejectedPacketCommit =
    "d647ea5591c7b982f34481ce83bab416bef549c5"

private func v06SHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func v06SHA256(_ url: URL) throws -> String {
    v06SHA256(try Data(contentsOf: url))
}

private func v06CanonicalData(_ value: Any) throws -> Data {
    var data = try JSONSerialization.data(
        withJSONObject: value,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    return data
}

private func v06Object(_ url: URL) throws -> [String: Any] {
    guard let object = try JSONSerialization.jsonObject(
        with: Data(contentsOf: url)
    ) as? [String: Any] else {
        throw IndustrialL2V06RepairError.invalid(
            "could not decode \(url.path)"
        )
    }
    return object
}

private func v06WriteJSON(_ value: Any, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw IndustrialL2V06RepairError.invalid(
            "output must be absent: \(url.path)"
        )
    }
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try v06CanonicalData(value).write(to: url, options: .atomic)
}

private func v06SetBlock(
    _ blocks: inout [[String: Any]],
    id: String,
    dimensions: [Double],
    position: [Double],
    materialID: String? = nil,
    role: String
) throws {
    guard
        dimensions.count == 3,
        position.count == 3,
        dimensions.allSatisfy({ $0 > 0 }),
        let index = blocks.firstIndex(where: {
            $0["id"] as? String == id
        })
    else {
        throw IndustrialL2V06RepairError.invalid(
            "invalid or missing block \(id)"
        )
    }
    blocks[index]["dimensions"] = dimensions
    blocks[index]["positionWorld"] = position
    blocks[index]["presentationRole"] = role
    if let materialID {
        blocks[index]["materialID"] = materialID
    }
}

private func v06RepairNorth(
    _ blocks: inout [[String: Any]]
) throws {
    try v06SetBlock(
        &blocks,
        id: "n-production-plinth-west",
        dimensions: [26, 5, 30],
        position: [-13, 4.9, 10],
        role: "main production plinth behind the North frontage sightline"
    )
    try v06SetBlock(
        &blocks,
        id: "n-production-plinth-east",
        dimensions: [20, 3, 18],
        position: [17, 3.9, 12],
        role: "low East service-shed plinth"
    )
    try v06SetBlock(
        &blocks,
        id: "n-production-hall-west",
        dimensions: [25.6, 22, 29.6],
        position: [-13, 18.3, 10],
        role: "primary bulk shifted left and behind the loading facade"
    )
    try v06SetBlock(
        &blocks,
        id: "n-production-hall-east",
        dimensions: [19.6, 5, 17.6],
        position: [17, 8.2, 12],
        role: "service-shed-height foreground wing"
    )
    try v06SetBlock(
        &blocks,
        id: "n-loading-throat",
        dimensions: [38, 15, 3],
        position: [0, 9.5, -16.5],
        materialID: "v05-admin-concrete",
        role: "broad light North dock wall brought toward the socket"
    )
    for (id, x) in [
        ("n-dock-door-a", -12.0),
        ("n-dock-door-b", 0.0),
        ("n-dock-door-c", 12.0),
    ] {
        try v06SetBlock(
            &blocks,
            id: id,
            dimensions: [10, 12, 1.2],
            position: [x, 9, -14.4],
            role: "large dark North dock face"
        )
    }
    for (id, x) in [
        ("n-dock-canopy-a", -12.0),
        ("n-dock-canopy-b", 0.0),
        ("n-dock-canopy-c", 12.0),
    ] {
        try v06SetBlock(
            &blocks,
            id: id,
            dimensions: [11, 2.5, 6],
            position: [x, 16.6, -17],
            role: "light North dock frame and canopy"
        )
    }
    try v06SetBlock(
        &blocks,
        id: "n-loading-apron",
        dimensions: [40, 2.2, 12],
        position: [0, 1.1, -22],
        role: "short wide North socket-to-dock apron"
    )
    try v06SetBlock(
        &blocks,
        id: "n-portal-post-west",
        dimensions: [2.5, 20, 2.5],
        position: [-19, 12.5, -20],
        role: "subordinate North court marker"
    )
    try v06SetBlock(
        &blocks,
        id: "n-portal-post-east",
        dimensions: [2.5, 20, 2.5],
        position: [19, 12.5, -20],
        role: "subordinate North court marker"
    )
    try v06SetBlock(
        &blocks,
        id: "n-portal-header",
        dimensions: [40, 2.5, 2.5],
        position: [0, 22, -20],
        role: "subordinate ochre North logistics accent"
    )
    try v06SetBlock(
        &blocks,
        id: "n-admin-quality-wing",
        dimensions: [12, 10, 12],
        position: [21, 7.6, -20],
        role: "low North administration return outside the dock sightline"
    )
    try v06SetBlock(
        &blocks,
        id: "n-admin-glazing",
        dimensions: [9, 5, 1],
        position: [21, 9, -26.5],
        role: "North administration glazing"
    )
    try v06SetBlock(
        &blocks,
        id: "n-staff-door",
        dimensions: [1.2, 9, 6],
        position: [27.4, 7.5, -20],
        role: "large visible North return-side staff entrance"
    )
    try v06SetBlock(
        &blocks,
        id: "n-staff-canopy",
        dimensions: [6, 2, 8],
        position: [25, 13.5, -20],
        role: "North staff canopy distinct from loading bays"
    )
    try v06SetBlock(
        &blocks,
        id: "n-roof-west",
        dimensions: [27, 2.4, 31],
        position: [-13, 30.4, 10],
        role: "main production roof behind the frontage"
    )
    try v06SetBlock(
        &blocks,
        id: "n-roof-east",
        dimensions: [21, 2, 19],
        position: [17, 11.7, 12],
        role: "low service-shed roof"
    )
    try v06SetBlock(
        &blocks,
        id: "n-clerestory-west",
        dimensions: [12, 5, 8],
        position: [-15, 34, 7],
        role: "main hall daylight monitor"
    )
    try v06SetBlock(
        &blocks,
        id: "n-clerestory-east",
        dimensions: [8, 3, 6],
        position: [17, 14, 12],
        role: "subordinate service monitor"
    )
}

private func v06RepairWest(
    _ blocks: inout [[String: Any]]
) throws {
    try v06SetBlock(
        &blocks,
        id: "w-production-plinth-north",
        dimensions: [30, 5, 26],
        position: [10, 4.9, -13],
        role: "main production plinth behind the West frontage sightline"
    )
    try v06SetBlock(
        &blocks,
        id: "w-production-plinth-south",
        dimensions: [18, 3, 20],
        position: [12, 3.9, 17],
        role: "low South service-shed plinth"
    )
    try v06SetBlock(
        &blocks,
        id: "w-production-hall-north",
        dimensions: [29.6, 22, 25.6],
        position: [10, 18.3, -13],
        role: "primary bulk shifted north and behind the loading facade"
    )
    try v06SetBlock(
        &blocks,
        id: "w-production-hall-south",
        dimensions: [17.6, 5, 19.6],
        position: [12, 8.2, 17],
        role: "service-shed-height foreground wing"
    )
    try v06SetBlock(
        &blocks,
        id: "w-loading-throat",
        dimensions: [3, 15, 38],
        position: [-16.5, 9.5, 0],
        materialID: "v05-admin-concrete",
        role: "broad light West dock wall brought toward the socket"
    )
    for (id, z) in [
        ("w-dock-door-a", -12.0),
        ("w-dock-door-b", 0.0),
        ("w-dock-door-c", 12.0),
    ] {
        try v06SetBlock(
            &blocks,
            id: id,
            dimensions: [1.2, 12, 10],
            position: [-14.4, 9, z],
            role: "large dark West dock face"
        )
    }
    for (id, z) in [
        ("w-dock-canopy-a", -12.0),
        ("w-dock-canopy-b", 0.0),
        ("w-dock-canopy-c", 12.0),
    ] {
        try v06SetBlock(
            &blocks,
            id: id,
            dimensions: [6, 2.5, 11],
            position: [-17, 16.6, z],
            role: "light West dock frame and canopy"
        )
    }
    try v06SetBlock(
        &blocks,
        id: "w-loading-apron",
        dimensions: [12, 2.2, 40],
        position: [-22, 1.1, 0],
        role: "short wide West socket-to-dock apron"
    )
    try v06SetBlock(
        &blocks,
        id: "w-portal-post-north",
        dimensions: [2.5, 20, 2.5],
        position: [-20, 12.5, -19],
        role: "subordinate West court marker"
    )
    try v06SetBlock(
        &blocks,
        id: "w-portal-post-south",
        dimensions: [2.5, 20, 2.5],
        position: [-20, 12.5, 19],
        role: "subordinate West court marker"
    )
    try v06SetBlock(
        &blocks,
        id: "w-portal-header",
        dimensions: [2.5, 2.5, 40],
        position: [-20, 22, 0],
        role: "subordinate ochre West logistics accent"
    )
    try v06SetBlock(
        &blocks,
        id: "w-admin-quality-wing",
        dimensions: [12, 10, 12],
        position: [-20, 7.6, 21],
        role: "low West administration return outside the dock sightline"
    )
    try v06SetBlock(
        &blocks,
        id: "w-admin-glazing",
        dimensions: [9, 5, 1],
        position: [-20, 9, 27],
        role: "West administration glazing"
    )
    try v06SetBlock(
        &blocks,
        id: "w-staff-door",
        dimensions: [6, 9, 1.2],
        position: [-20, 7.5, 27.4],
        role: "large visible West return-side staff entrance"
    )
    try v06SetBlock(
        &blocks,
        id: "w-staff-canopy",
        dimensions: [8, 2, 6],
        position: [-20, 13.5, 25],
        role: "West staff canopy distinct from loading bays"
    )
    try v06SetBlock(
        &blocks,
        id: "w-roof-north",
        dimensions: [31, 2.4, 27],
        position: [10, 30.4, -13],
        role: "main production roof behind the frontage"
    )
    try v06SetBlock(
        &blocks,
        id: "w-roof-south",
        dimensions: [19, 2, 21],
        position: [12, 11.7, 17],
        role: "low service-shed roof"
    )
    try v06SetBlock(
        &blocks,
        id: "w-clerestory-north",
        dimensions: [8, 5, 12],
        position: [7, 34, -15],
        role: "main hall daylight monitor"
    )
    try v06SetBlock(
        &blocks,
        id: "w-clerestory-south",
        dimensions: [6, 3, 8],
        position: [12, 14, 17],
        role: "subordinate service monitor"
    )
}

@main
enum RepairIndustrialL2DirectionalFamilyV06FrontageFirstMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard
            let rootIndex = arguments.firstIndex(of: "--repository-root"),
            rootIndex + 1 < arguments.count
        else {
            throw IndustrialL2V06RepairError.invalid(
                "usage: repair-industrial-l2-v06 --repository-root <path>"
            )
        }
        let root = URL(
            fileURLWithPath: arguments[rootIndex + 1]
        ).standardizedFileURL
        func outputURL(_ name: String, fallback: URL) -> URL {
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
        let artRoot = outputURL(
            "--art-output-root",
            fallback: root.appendingPathComponent(
                "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-directional-family-v06"
            )
        )
        let evidenceRoot = outputURL(
            "--evidence-output-root",
            fallback: root.appendingPathComponent(
                "docs/production/evidence/PLAY-027/industrial-l02/l02/directional-family-v06/prepixel"
            )
        )
        guard
            artRoot.path.contains(
                "industrial-l02-directional-family-v06"
            ),
            evidenceRoot.path.contains(
                "industrial-l02/l02/directional-family-v06/prepixel"
            ),
            !FileManager.default.fileExists(atPath: artRoot.path),
            !FileManager.default.fileExists(atPath: evidenceRoot.path)
        else {
            throw IndustrialL2V06RepairError.invalid(
                "V06 outputs must be absent and task-owned"
            )
        }

        let inputRoot = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-directional-family-v05/scenes/industrial_l02/variant-0"
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
            try v06SHA256(eastDescriptorURL)
                == v06EastDescriptorSHA256,
            try v06SHA256(eastRawURL) == v06EastRawSHA256,
            try v06SHA256(materialsURL) == v06MaterialsSHA256
        else {
            throw IndustrialL2V06RepairError.invalid(
                "immutable East/material input drift"
            )
        }
        let decoder = JSONDecoder()
        let materialLibrary = try decoder.decode(
            MaterialLibraryDescriptor.self,
            from: Data(contentsOf: materialsURL)
        )
        let materialIDs = Set(materialLibrary.materials.map(\.id))
        var records: [[String: Any]] = []
        var outputHashes: Set<String> = []

        for direction in ["north", "west"] {
            let inputURL = inputRoot.appendingPathComponent(
                "\(direction)/scene.json"
            )
            guard try v06SHA256(inputURL) == v06InputHashes[direction] else {
                throw IndustrialL2V06RepairError.invalid(
                    "\(direction) V05 input drift"
                )
            }
            var object = try v06Object(inputURL)
            object["sourceRevision"] = "source-v09"
            object["sceneGeometryID"] =
                "industrial-l02-\(direction)-frontage-first-geometry-v04"
            guard
                var sampling = object["sampling"] as? [String: Any],
                var building = object["building"] as? [String: Any],
                var blocks = building["massBlocks"] as? [[String: Any]]
            else {
                throw IndustrialL2V06RepairError.invalid(
                    "\(direction) descriptor structure drift"
                )
            }
            sampling["sourceRevisionBinding"] = "source-v09"
            object["sampling"] = sampling
            if direction == "north" {
                try v06RepairNorth(&blocks)
                object["occlusionExclusions"] = [[
                    "id": "north-v06-frontage-semantic-sightline",
                    "polygonWorld": [
                        [-20.0, -28.0],
                        [20.0, -28.0],
                        [20.0, -13.0],
                        [-20.0, -13.0],
                    ],
                    "purpose":
                        "protect three visible dock faces, frames, apron, and return-side staff entry",
                ]]
            } else {
                try v06RepairWest(&blocks)
                object["occlusionExclusions"] = [[
                    "id": "west-v06-frontage-semantic-sightline",
                    "polygonWorld": [
                        [-28.0, -20.0],
                        [-13.0, -20.0],
                        [-13.0, 20.0],
                        [-28.0, 20.0],
                    ],
                    "purpose":
                        "protect three visible dock faces, frames, apron, and return-side staff entry",
                ]]
            }
            building["massBlocks"] = blocks
            object["building"] = building
            if var authority =
                object["prePixelFamilyAuthority"] as? [String: Any]
            {
                authority["scope"] =
                    "Industrial L2 \(direction) source-v09 semantic visibility gate only"
                authority["sourceAuthorityPixels"] = false
                authority["productionSelected"] = false
                object["prePixelFamilyAuthority"] = authority
            }
            let output = artRoot.appendingPathComponent(
                "scenes/industrial_l02/variant-0/\(direction)/scene.json"
            )
            try v06WriteJSON(object, to: output)
            let decoded = try decoder.decode(
                SceneDescriptor.self,
                from: Data(contentsOf: output)
            )
            let blocksDecoded = decoded.building.massBlocks ?? []
            var refs = Set(blocksDecoded.map(\.materialID))
            refs.formUnion(decoded.props.map(\.materialID))
            let missing = refs.subtracting(materialIDs)
            let expectedSocket =
                direction == "north" ? [896.0, 704.0] : [640.0, 704.0]
            let doors = blocksDecoded.filter {
                $0.id.contains("dock-door")
            }
            let staff = blocksDecoded.filter {
                $0.id.contains("staff-door")
            }
            guard
                decoded.sourceRevision == "source-v09",
                decoded.productionSelected == false,
                decoded.viewDirection == direction,
                decoded.building.usesExplicitComponentGeometry == true,
                decoded.registration.groundPivotSource == [768, 896],
                decoded.registration.frontageSocketSource == expectedSocket,
                missing.isEmpty,
                doors.count == 3,
                doors.allSatisfy({
                    $0.dimensions[1] >= 12
                        && max($0.dimensions[0], $0.dimensions[2]) >= 10
                }),
                staff.count == 1,
                staff[0].dimensions[1] >= 9,
                max(
                    staff[0].dimensions[0],
                    staff[0].dimensions[2]
                ) >= 6
            else {
                throw IndustrialL2V06RepairError.invalid(
                    "\(direction) V06 descriptor validation failed"
                )
            }
            let outputHash = try v06SHA256(output)
            outputHashes.insert(outputHash)
            records.append([
                "direction": direction,
                "inputDescriptorSHA256": v06InputHashes[direction]!,
                "outputDescriptorSHA256": outputHash,
                "dockFaceWorldDimensions": doors.map(\.dimensions),
                "staffDoorWorldDimensions": staff[0].dimensions,
                "productionDecodePassed": true,
                "materialReferencesPassed": true,
                "pivotSocketCameraLightPreserved": true,
                "semanticTargetsDeclared": [
                    "\(direction.prefix(1))-dock-door-a",
                    "\(direction.prefix(1))-dock-door-b",
                    "\(direction.prefix(1))-dock-door-c",
                    "\(direction.prefix(1))-staff-door",
                ],
                "sourceAuthority": false,
                "productionSelected": false,
            ])
        }
        guard outputHashes.count == 2 else {
            throw IndustrialL2V06RepairError.invalid(
                "repaired descriptors alias"
            )
        }
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type":
                "industrial-l02-directional-family-v06-frontage-first-prepixel-contract",
            "inputVisualRejectionCommit": v06RejectedPacketCommit,
            "directions": records,
            "semanticGate": [
                "renderer":
                    "exact production ContractSceneBuilder camera and geometry; diagnostic constant semantic materials",
                "native2xCanvasPixels": [432, 288],
                "native2xScale": 0.28125,
                "minimumTargetBoundsPixels": [6, 8],
                "minimumDockSiblingSeparationPixels": 2,
                "targetsPerDirection": 4,
                "sourceAuthority": false,
            ],
            "immutableEastDescriptorSHA256":
                v06EastDescriptorSHA256,
            "immutableEastRawSHA256": v06EastRawSHA256,
            "immutableMaterialsSHA256": v06MaterialsSHA256,
            "southMutationCount": 0,
            "sceneKitProcessCount": 0,
            "metalProcessCount": 0,
            "rawSourcePixelCount": 0,
            "normalizerProcessCount": 0,
            "sourceAuthority": false,
            "productionSelected": false,
            "passed": true,
        ]
        try v06WriteJSON(
            report,
            to: evidenceRoot.appendingPathComponent(
                "PREPIXEL-CONTRACT.json"
            )
        )
        print("PASS directions=2 targets=8 rawSourcePixels=0")
    }
}
