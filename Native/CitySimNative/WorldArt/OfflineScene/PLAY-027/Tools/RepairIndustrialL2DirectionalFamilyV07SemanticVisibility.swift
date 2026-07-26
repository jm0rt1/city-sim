import CryptoKit
import Foundation

enum IndustrialL2V07RepairError: Error, CustomStringConvertible {
    case invalid(String)

    var description: String {
        switch self {
        case let .invalid(message):
            return message
        }
    }
}

private struct V07BlockRepair {
    let id: String
    let dimensions: [Double]?
    let positionWorld: [Double]?
    let presentationRole: String?
}

private let v07InputHashes = [
    "north":
        "6a51cf80436a5e0626ce869e9178c80844e979758419b8c509da0a651af4b390",
    "west":
        "2ef1b01ddb5eee3eda3f0e859d7e9bec5572dddce53a6f6502c202504b345fd5",
]
private let v07EastDescriptorSHA256 =
    "a7732ba762b4569b50a1dc19291d42b2c4030cf21509a242caad49eea339b517"
private let v07EastRawSHA256 =
    "a32725fd0ea0436c1f8a13d319c3c66408a7cdf44ff8f2cdb72665839dd685a8"
private let v07MaterialsSHA256 =
    "6ab8b19d6d6cf53dc98f77867117569f6cccd104cd886a2dc1788361736404fb"
private let v07SemanticRejectionCommit =
    "40c85fa917dd219aff1f32207396e38a403f107c"

private func v07SHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func v07SHA256(_ url: URL) throws -> String {
    v07SHA256(try Data(contentsOf: url))
}

private func v07CanonicalData(_ value: Any) throws -> Data {
    var data = try JSONSerialization.data(
        withJSONObject: value,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    return data
}

private func v07CanonicalSHA256(_ value: Any) throws -> String {
    v07SHA256(try v07CanonicalData(value))
}

private func v07Object(_ url: URL) throws -> [String: Any] {
    guard let object = try JSONSerialization.jsonObject(
        with: Data(contentsOf: url)
    ) as? [String: Any] else {
        throw IndustrialL2V07RepairError.invalid(
            "could not decode \(url.path)"
        )
    }
    return object
}

private func v07WriteJSON(_ value: Any, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw IndustrialL2V07RepairError.invalid(
            "output must be absent: \(url.path)"
        )
    }
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try v07CanonicalData(value).write(to: url, options: .atomic)
}

private func v07BlockMap(
    _ blocks: [[String: Any]]
) throws -> [String: [String: Any]] {
    var result: [String: [String: Any]] = [:]
    for block in blocks {
        guard
            let id = block["id"] as? String,
            result[id] == nil
        else {
            throw IndustrialL2V07RepairError.invalid(
                "missing or duplicate mass-block ID"
            )
        }
        result[id] = block
    }
    return result
}

private func v07Repairs(_ direction: String) -> [V07BlockRepair] {
    if direction == "north" {
        return [
            V07BlockRepair(
                id: "n-production-plinth-west",
                dimensions: [18, 5, 30],
                positionWorld: [-19, 4.9, 10],
                presentationRole:
                    "narrow main plinth shifted outside the dock A sightline"
            ),
            V07BlockRepair(
                id: "n-production-hall-west",
                dimensions: [17.6, 22, 29.6],
                positionWorld: [-19, 18.3, 10],
                presentationRole:
                    "main production bulk shortened and shifted west of dock A"
            ),
            V07BlockRepair(
                id: "n-roof-west",
                dimensions: [20, 2.4, 31],
                positionWorld: [-18, 30.4, 10],
                presentationRole:
                    "main production roof aligned behind the exposed frontage"
            ),
            V07BlockRepair(
                id: "n-clerestory-west",
                dimensions: [8, 5, 8],
                positionWorld: [-21, 34, 7],
                presentationRole:
                    "compact main hall monitor outside the dock A sightline"
            ),
            V07BlockRepair(
                id: "n-dock-door-a",
                dimensions: nil,
                positionWorld: [-13, 9, -14.4],
                presentationRole: nil
            ),
            V07BlockRepair(
                id: "n-dock-door-c",
                dimensions: nil,
                positionWorld: [13, 9, -14.4],
                presentationRole: nil
            ),
            V07BlockRepair(
                id: "n-dock-canopy-a",
                dimensions: nil,
                positionWorld: [-13, 16.6, -17],
                presentationRole: nil
            ),
            V07BlockRepair(
                id: "n-dock-canopy-c",
                dimensions: nil,
                positionWorld: [13, 16.6, -17],
                presentationRole: nil
            ),
        ]
    }
    return [
        V07BlockRepair(
            id: "w-production-plinth-north",
            dimensions: [30, 5, 18],
            positionWorld: [10, 4.9, -19],
            presentationRole:
                "narrow main plinth shifted outside the dock A sightline"
        ),
        V07BlockRepair(
            id: "w-production-hall-north",
            dimensions: [29.6, 22, 17.6],
            positionWorld: [10, 18.3, -19],
            presentationRole:
                "main production bulk shortened and shifted north of dock A"
        ),
        V07BlockRepair(
            id: "w-roof-north",
            dimensions: [31, 2.4, 20],
            positionWorld: [10, 30.4, -18],
            presentationRole:
                "main production roof aligned behind the exposed frontage"
        ),
        V07BlockRepair(
            id: "w-clerestory-north",
            dimensions: [8, 5, 8],
            positionWorld: [7, 34, -21],
            presentationRole:
                "compact main hall monitor outside the dock A sightline"
        ),
        V07BlockRepair(
            id: "w-dock-door-a",
            dimensions: nil,
            positionWorld: [-14.4, 9, -13],
            presentationRole: nil
        ),
        V07BlockRepair(
            id: "w-dock-door-c",
            dimensions: nil,
            positionWorld: [-14.4, 9, 13],
            presentationRole: nil
        ),
        V07BlockRepair(
            id: "w-dock-canopy-a",
            dimensions: nil,
            positionWorld: [-17, 16.6, -13],
            presentationRole: nil
        ),
        V07BlockRepair(
            id: "w-dock-canopy-c",
            dimensions: nil,
            positionWorld: [-17, 16.6, 13],
            presentationRole: nil
        ),
    ]
}

private func v07Apply(
    _ repairs: [V07BlockRepair],
    to blocks: inout [[String: Any]]
) throws {
    for repair in repairs {
        guard let index = blocks.firstIndex(where: {
            $0["id"] as? String == repair.id
        }) else {
            throw IndustrialL2V07RepairError.invalid(
                "missing repair target \(repair.id)"
            )
        }
        if let dimensions = repair.dimensions {
            guard
                dimensions.count == 3,
                dimensions.allSatisfy({ $0 > 0 })
            else {
                throw IndustrialL2V07RepairError.invalid(
                    "invalid dimensions for \(repair.id)"
                )
            }
            blocks[index]["dimensions"] = dimensions
        }
        if let positionWorld = repair.positionWorld {
            guard positionWorld.count == 3 else {
                throw IndustrialL2V07RepairError.invalid(
                    "invalid position for \(repair.id)"
                )
            }
            blocks[index]["positionWorld"] = positionWorld
        }
        if let presentationRole = repair.presentationRole {
            blocks[index]["presentationRole"] = presentationRole
        }
    }
}

private func v07ImmutableContract(
    _ object: [String: Any]
) throws -> [String: Any] {
    let keys = [
        "camera",
        "eastReviewAnchor",
        "light",
        "materialLibrary",
        "registration",
        "styleAnchor",
        "toolchainFingerprint",
    ]
    var result: [String: Any] = [:]
    for key in keys {
        guard let value = object[key] else {
            throw IndustrialL2V07RepairError.invalid(
                "missing immutable key \(key)"
            )
        }
        result[key] = value
    }
    return result
}

@main
enum RepairIndustrialL2DirectionalFamilyV07SemanticVisibilityMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard
            let rootIndex = arguments.firstIndex(of: "--repository-root"),
            rootIndex + 1 < arguments.count
        else {
            throw IndustrialL2V07RepairError.invalid(
                "usage: repair-industrial-l2-v07 --repository-root <path>"
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
                "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-directional-family-v07"
            )
        )
        let evidenceRoot = outputURL(
            "--evidence-output-root",
            fallback: root.appendingPathComponent(
                "docs/production/evidence/PLAY-027/industrial-l02/l02/directional-family-v07/prepixel"
            )
        )
        guard
            artRoot.path.contains(
                "industrial-l02-directional-family-v07"
            ),
            evidenceRoot.path.contains(
                "industrial-l02/l02/directional-family-v07/prepixel"
            ),
            !FileManager.default.fileExists(atPath: artRoot.path),
            !FileManager.default.fileExists(atPath: evidenceRoot.path)
        else {
            throw IndustrialL2V07RepairError.invalid(
                "V07 outputs must be absent and task-owned"
            )
        }

        let inputRoot = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-directional-family-v06/scenes/industrial_l02/variant-0"
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
            try v07SHA256(eastDescriptorURL)
                == v07EastDescriptorSHA256,
            try v07SHA256(eastRawURL) == v07EastRawSHA256,
            try v07SHA256(materialsURL) == v07MaterialsSHA256
        else {
            throw IndustrialL2V07RepairError.invalid(
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
            guard try v07SHA256(inputURL) == v07InputHashes[direction] else {
                throw IndustrialL2V07RepairError.invalid(
                    "\(direction) V06 input drift"
                )
            }
            let inputObject = try v07Object(inputURL)
            let immutableContractHash = try v07CanonicalSHA256(
                v07ImmutableContract(inputObject)
            )
            var object = inputObject
            object["sourceRevision"] = "source-v10"
            object["sceneGeometryID"] =
                "industrial-l02-\(direction)-semantic-visibility-geometry-v05"
            guard
                var sampling = object["sampling"] as? [String: Any],
                var building = object["building"] as? [String: Any],
                var blocks = building["massBlocks"] as? [[String: Any]],
                let inputBuilding = inputObject["building"]
                    as? [String: Any],
                let inputBlocks = inputBuilding["massBlocks"]
                    as? [[String: Any]]
            else {
                throw IndustrialL2V07RepairError.invalid(
                    "\(direction) descriptor structure drift"
                )
            }
            let beforeBlocks = try v07BlockMap(inputBlocks)
            let repairs = v07Repairs(direction)
            try v07Apply(repairs, to: &blocks)
            let afterBlocks = try v07BlockMap(blocks)
            let expectedChangedIDs = Set(repairs.map(\.id))
            var actualChangedIDs: Set<String> = []
            for (id, before) in beforeBlocks {
                guard let after = afterBlocks[id] else {
                    throw IndustrialL2V07RepairError.invalid(
                        "\(direction) removed block \(id)"
                    )
                }
                if try v07CanonicalData(before)
                    != v07CanonicalData(after)
                {
                    actualChangedIDs.insert(id)
                }
            }
            guard
                beforeBlocks.count == afterBlocks.count,
                actualChangedIDs == expectedChangedIDs
            else {
                throw IndustrialL2V07RepairError.invalid(
                    "\(direction) changed-block scope drift"
                )
            }

            sampling["sourceRevisionBinding"] = "source-v10"
            object["sampling"] = sampling
            building["massBlocks"] = blocks
            object["building"] = building
            object["occlusionExclusions"] = [[
                "id":
                    "\(direction)-v07-semantic-visibility-sightline",
                "polygonWorld": direction == "north"
                    ? [
                        [-20.0, -28.0],
                        [20.0, -28.0],
                        [20.0, -13.0],
                        [-20.0, -13.0],
                    ]
                    : [
                        [-28.0, -20.0],
                        [-13.0, -20.0],
                        [-13.0, 20.0],
                        [-28.0, 20.0],
                    ],
                "purpose":
                    "require independently visible dock A/B/C faces, two-pixel sibling gaps, and the return-side staff entrance",
            ]]
            if var authority =
                object["prePixelFamilyAuthority"] as? [String: Any]
            {
                authority["scope"] =
                    "Industrial L2 \(direction) source-v10 semantic visibility gate only"
                authority["sourceAuthorityPixels"] = false
                authority["productionSelected"] = false
                object["prePixelFamilyAuthority"] = authority
            }

            let outputURL = artRoot.appendingPathComponent(
                "scenes/industrial_l02/variant-0/\(direction)/scene.json"
            )
            try v07WriteJSON(object, to: outputURL)
            let decoded = try decoder.decode(
                SceneDescriptor.self,
                from: Data(contentsOf: outputURL)
            )
            let decodedBlocks = decoded.building.massBlocks ?? []
            let decodedMap = Dictionary(
                uniqueKeysWithValues: decodedBlocks.map { ($0.id, $0) }
            )
            var refs = Set(decodedBlocks.map(\.materialID))
            refs.formUnion(decoded.props.map(\.materialID))
            let missing = refs.subtracting(materialIDs)
            let prefix = String(direction.prefix(1))
            let doorIDs = [
                "\(prefix)-dock-door-a",
                "\(prefix)-dock-door-b",
                "\(prefix)-dock-door-c",
            ]
            let canopyIDs = [
                "\(prefix)-dock-canopy-a",
                "\(prefix)-dock-canopy-b",
                "\(prefix)-dock-canopy-c",
            ]
            let doors = doorIDs.compactMap { decodedMap[$0] }
            let canopies = canopyIDs.compactMap { decodedMap[$0] }
            guard
                doors.count == 3,
                canopies.count == 3,
                let staff = decodedMap["\(prefix)-staff-door"],
                let inputStaff = beforeBlocks[
                    "\(prefix)-staff-door"
                ],
                let outputStaff = afterBlocks[
                    "\(prefix)-staff-door"
                ]
            else {
                throw IndustrialL2V07RepairError.invalid(
                    "\(direction) target block lookup failed"
                )
            }
            let doorCenters = direction == "north"
                ? doors.map { $0.positionWorld[0] }
                : doors.map { $0.positionWorld[2] }
            let doorWidths = direction == "north"
                ? doors.map { $0.dimensions[0] }
                : doors.map { $0.dimensions[2] }
            let expectedSocket =
                direction == "north" ? [896.0, 704.0] : [640.0, 704.0]
            guard
                decoded.sourceRevision == "source-v10",
                decoded.productionSelected == false,
                decoded.viewDirection == direction,
                decoded.building.usesExplicitComponentGeometry == true,
                decoded.registration.groundPivotSource == [768, 896],
                decoded.registration.frontageSocketSource == expectedSocket,
                missing.isEmpty,
                doorCenters == [-13, 0, 13],
                doorWidths == [10, 10, 10],
                doors.allSatisfy({
                    $0.dimensions[1] == 12
                }),
                canopies.count == 3,
                try v07CanonicalData(inputStaff)
                    == v07CanonicalData(outputStaff),
                max(staff.dimensions[0], staff.dimensions[2]) >= 6,
                staff.dimensions[1] >= 9,
                try v07CanonicalSHA256(
                    v07ImmutableContract(object)
                ) == immutableContractHash
            else {
                throw IndustrialL2V07RepairError.invalid(
                    "\(direction) V07 descriptor validation failed"
                )
            }

            let outputHash = try v07SHA256(outputURL)
            outputHashes.insert(outputHash)
            records.append([
                "direction": direction,
                "inputDescriptorSHA256": v07InputHashes[direction]!,
                "outputDescriptorSHA256": outputHash,
                "changedMassBlockIDs":
                    actualChangedIDs.sorted(),
                "doorCenterWorldCoordinates": doorCenters,
                "doorFaceWorldWidths": doorWidths,
                "doorFaceWorldHeights":
                    doors.map { $0.dimensions[1] },
                "doorMaterials":
                    doors.map(\.materialID),
                "staffDoorCanonicalSHA256":
                    try v07CanonicalSHA256(inputStaff),
                "immutableCameraPivotSocketLightMaterialHash":
                    immutableContractHash,
                "productionDecodePassed": true,
                "materialReferencesPassed": true,
                "sourceAuthority": false,
                "productionSelected": false,
            ])
        }

        guard outputHashes.count == 2 else {
            throw IndustrialL2V07RepairError.invalid(
                "V07 descriptors alias"
            )
        }
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type":
                "industrial-l02-directional-family-v07-semantic-visibility-prepixel-contract",
            "inputSemanticRejectionCommit":
                v07SemanticRejectionCommit,
            "directions": records,
            "repairBoundary": [
                "dockAFaceWidthChangeWorld": 0,
                "dockFaceDimensionsMaterialDepthPreserved": true,
                "outerDockCenterShiftWorld": 1,
                "foregroundBulkShortenedAndShifted": true,
                "staffDoorPreserved": true,
                "validDockBCFaceGeometryPreserved": true,
            ],
            "semanticGate": [
                "renderer":
                    "exact production ContractSceneBuilder camera and geometry; diagnostic constant semantic materials",
                "native2xCanvasPixels": [432, 288],
                "minimumTargetBoundsPixels": [6, 8],
                "minimumDockSiblingSeparationPixels": 2,
                "targetsPerDirection": 4,
            ],
            "immutableEastDescriptorSHA256":
                v07EastDescriptorSHA256,
            "immutableEastRawSHA256": v07EastRawSHA256,
            "immutableMaterialsSHA256": v07MaterialsSHA256,
            "southMutationCount": 0,
            "sceneKitProcessCount": 0,
            "metalProcessCount": 0,
            "rawSourcePixelCount": 0,
            "normalizerProcessCount": 0,
            "sourceAuthority": false,
            "productionSelected": false,
            "passed": true,
        ]
        try v07WriteJSON(
            report,
            to: evidenceRoot.appendingPathComponent(
                "PREPIXEL-CONTRACT.json"
            )
        )
        print("PASS directions=2 targets=8 rawSourcePixels=0")
    }
}
