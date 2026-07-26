import CryptoKit
import Foundation

enum IndustrialL2EastV06MetadataRepairError:
    Error,
    CustomStringConvertible
{
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return """
            usage: repair-industrial-l2-east-v06-metadata \
              --repository-root <path> \
              [--art-output-root <path>] \
              [--evidence-output-root <path>]
            """
        case let .invalid(message):
            return message
        }
    }
}

private let eastV06V05DescriptorSHA256 =
    "482bea0169e9229df437b05ca6f0299046d49bb92e2e9d9ef4f3865df9be5fa0"
private let eastV06MaterialLibrarySHA256 =
    "6ab8b19d6d6cf53dc98f77867117569f6cccd104cd886a2dc1788361736404fb"
private let eastV06RawSHA256 =
    "a32725fd0ea0436c1f8a13d319c3c66408a7cdf44ff8f2cdb72665839dd685a8"
private let eastV06CanonicalGeometrySHA256 =
    "6c727c4b7053d69578e97c2f73cf3054cd2dda106bf06625e0dac12a356798fb"
private let eastV06Revision =
    "east-quality-calibration-art-proof-v06-metadata-compatible"

private func eastV06Argument(
    _ name: String,
    in arguments: [String],
    required: Bool = true
) throws -> String? {
    guard let index = arguments.firstIndex(of: name) else {
        if required {
            throw IndustrialL2EastV06MetadataRepairError.arguments
        }
        return nil
    }
    guard index + 1 < arguments.count else {
        throw IndustrialL2EastV06MetadataRepairError.arguments
    }
    return arguments[index + 1]
}

private func eastV06SHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func eastV06SHA256(_ url: URL) throws -> String {
    eastV06SHA256(try Data(contentsOf: url))
}

private func eastV06CanonicalData(_ value: Any) throws -> Data {
    var data = try JSONSerialization.data(
        withJSONObject: value,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    return data
}

private func eastV06Object(_ url: URL) throws -> [String: Any] {
    guard
        let object = try JSONSerialization.jsonObject(
            with: Data(contentsOf: url)
        ) as? [String: Any]
    else {
        throw IndustrialL2EastV06MetadataRepairError.invalid(
            "could not decode \(url.path)"
        )
    }
    return object
}

private func eastV06WriteJSON(_ value: Any, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw IndustrialL2EastV06MetadataRepairError.invalid(
            "output must be absent: \(url.path)"
        )
    }
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try eastV06CanonicalData(value).write(to: url, options: .atomic)
}

private func eastV06MaterialReferences(
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
    result.formUnion(
        (descriptor.building.roofVolumes ?? []).map(\.materialID)
    )
    result.formUnion(
        (descriptor.building.trimBands ?? []).map(\.materialID)
    )
    for facade in descriptor.facades {
        result.insert(facade.materialID)
        result.formUnion(facade.windowBays.map(\.materialID))
        result.formUnion(
            (facade.windowRhythms ?? []).map(\.materialID)
        )
    }
    result.formUnion(descriptor.props.map(\.materialID))
    return result
}

private func eastV06RenderConsumedPayload(
    _ descriptor: [String: Any]
) throws -> [String: Any] {
    guard
        let building = descriptor["building"] as? [String: Any],
        descriptor["camera"] is [String: Any],
        descriptor["light"] is [String: Any],
        descriptor["registration"] is [String: Any],
        descriptor["sampling"] is [String: Any],
        let foundationMaterialID =
            building["foundationMaterialID"],
        let foundationDimensions =
            building["foundationDimensions"],
        let foundationPositionWorld =
            building["foundationPositionWorld"],
        let massBlocks = building["massBlocks"],
        let roofVolumes = building["roofVolumes"],
        let trimBands = building["trimBands"]
    else {
        throw IndustrialL2EastV06MetadataRepairError.invalid(
            "render-consumed payload inputs are incomplete"
        )
    }
    var sampling = descriptor["sampling"] as! [String: Any]
    sampling.removeValue(forKey: "sourceRevisionBinding")
    return [
        "materialLibrary": descriptor["materialLibrary"]!,
        "foundation": [
            "materialID": foundationMaterialID,
            "dimensions": foundationDimensions,
            "positionWorld": foundationPositionWorld,
        ],
        "massBlocks": massBlocks,
        "roofVolumes": roofVolumes,
        "trimBands": trimBands,
        "props": descriptor["props"]!,
        "registration": descriptor["registration"]!,
        "camera": descriptor["camera"]!,
        "light": descriptor["light"]!,
        "samplingWithoutRevisionBinding": sampling,
    ]
}

private func eastV06Inventory(
    _ directory: URL,
    repositoryRoot: URL
) throws -> (
    count: Int,
    digest: String,
    raw: [[String: String]]
) {
    guard
        let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [
                .isRegularFileKey
            ],
            options: [.skipsHiddenFiles]
        )
    else {
        throw IndustrialL2EastV06MetadataRepairError.invalid(
            "could not enumerate \(directory.path)"
        )
    }
    let prefix = repositoryRoot.path + "/"
    var rows: [[String: String]] = []
    for case let file as URL in enumerator {
        let values = try file.resourceValues(
            forKeys: [.isRegularFileKey]
        )
        guard values.isRegularFile == true else {
            continue
        }
        let path = file.path.hasPrefix(prefix)
            ? String(file.path.dropFirst(prefix.count))
            : file.path
        rows.append([
            "file": path,
            "sha256": try eastV06SHA256(file),
        ])
    }
    rows.sort {
        $0["file"]! < $1["file"]!
    }
    let digestRows = rows.map {
        "\($0["file"]!) \($0["sha256"]!)"
    }.joined(separator: "\n")
    return (
        rows.count,
        eastV06SHA256(Data(digestRows.utf8)),
        rows
    )
}

@main
enum RepairIndustrialL2EastV06MetadataCompatibilityMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath:
                try eastV06Argument(
                    "--repository-root",
                    in: arguments
                )!
        ).standardizedFileURL
        let artRoot = URL(
            fileURLWithPath:
                try eastV06Argument(
                    "--art-output-root",
                    in: arguments,
                    required: false
                ) ?? root.appendingPathComponent(
                    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-east-calibration-v06"
                ).path
        ).standardizedFileURL
        let evidenceRoot = URL(
            fileURLWithPath:
                try eastV06Argument(
                    "--evidence-output-root",
                    in: arguments,
                    required: false
                ) ?? root.appendingPathComponent(
                    "docs/production/evidence/PLAY-027/industrial-l02/l02/east-calibration-v06-metadata-compatibility"
                ).path
        ).standardizedFileURL
        guard
            artRoot.path.contains(
                "industrial-l02-east-calibration-v06"
            ),
            evidenceRoot.path.contains(
                "east-calibration-v06-metadata-compatibility"
            ),
            !FileManager.default.fileExists(atPath: artRoot.path),
            !FileManager.default.fileExists(atPath: evidenceRoot.path)
        else {
            throw IndustrialL2EastV06MetadataRepairError.invalid(
                "outputs must be absent and task-owned"
            )
        }

        let v05DescriptorURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-east-calibration-v05/scenes/industrial_l02/variant-0/east/scene.json"
        )
        let materialsURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-east-calibration-v05/materials/industrial-l02-east-calibration-v05.json"
        )
        let rawURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/east-calibration-v05/raw-calibration/diagnostics/east-primary/raw.png"
        )
        let v05EvidenceRoot = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/east-calibration-v05"
        )
        let rendererSourceURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/OfflineSceneRenderer.swift"
        )
        guard
            try eastV06SHA256(v05DescriptorURL)
                == eastV06V05DescriptorSHA256,
            try eastV06SHA256(materialsURL)
                == eastV06MaterialLibrarySHA256,
            try eastV06SHA256(rawURL)
                == eastV06RawSHA256
        else {
            throw IndustrialL2EastV06MetadataRepairError.invalid(
                "immutable East v05 descriptor/material/raw drift"
            )
        }

        let decoder = JSONDecoder()
        let materials = try decoder.decode(
            MaterialLibraryDescriptor.self,
            from: Data(contentsOf: materialsURL)
        )
        let materialIDs = Set(materials.materials.map(\.id))
        guard
            materialIDs.contains("v05-hall-metal"),
            !materialIDs.contains("v02-painted-steel")
        else {
            throw IndustrialL2EastV06MetadataRepairError.invalid(
                "material compatibility premise drift"
            )
        }

        let v05 = try eastV06Object(v05DescriptorURL)
        guard
            v05["sourceRevision"] as? String
                == "east-quality-calibration-art-proof-v05",
            var entrance = v05["entrance"] as? [String: Any],
            entrance["pavilionMaterialID"] as? String
                == "v02-painted-steel",
            var sampling = v05["sampling"] as? [String: Any],
            sampling["sourceRevisionBinding"] as? String
                == "east-quality-calibration-art-proof-v05",
            let building = v05["building"] as? [String: Any],
            building["usesExplicitComponentGeometry"] as? Bool
                == true
        else {
            throw IndustrialL2EastV06MetadataRepairError.invalid(
                "East v05 metadata premise drift"
            )
        }

        var v06 = v05
        v06["sourceRevision"] = eastV06Revision
        entrance["pavilionMaterialID"] = "v05-hall-metal"
        v06["entrance"] = entrance
        var v06Building = building
        guard
            var chimney =
                v06Building["chimney"] as? [String: Any],
            chimney["materialID"] as? String
                == "v04-process-metal",
            let v05Facades =
                v05["facades"] as? [[String: Any]]
        else {
            throw IndustrialL2EastV06MetadataRepairError.invalid(
                "East v05 skipped chimney/facade metadata premise drift"
            )
        }
        chimney["materialID"] = "v05-process-metal"
        v06Building["chimney"] = chimney
        v06["building"] = v06Building
        v06["facades"] = try v05Facades.map { facade in
            guard
                let direction = facade["direction"] as? String,
                let materialID = facade["materialID"] as? String
            else {
                throw IndustrialL2EastV06MetadataRepairError.invalid(
                    "East v05 facade metadata is incomplete"
                )
            }
            var repaired = facade
            switch (direction, materialID) {
            case ("east", "v04-corrugated-hall"):
                repaired["materialID"] = "v05-hall-metal"
            case (
                "north",
                "v04-formed-concrete"
            ), (
                "south",
                "v04-formed-concrete"
            ), (
                "west",
                "v04-formed-concrete"
            ):
                repaired["materialID"] = "v05-admin-concrete"
            default:
                throw IndustrialL2EastV06MetadataRepairError.invalid(
                    "East v05 facade mapping is not an approved compatibility class: \(direction)=\(materialID)"
                )
            }
            return repaired
        }
        sampling["sourceRevisionBinding"] = eastV06Revision
        v06["sampling"] = sampling
        let outputURL = artRoot.appendingPathComponent(
            "scenes/industrial_l02/variant-0/east/scene.json"
        )
        try eastV06WriteJSON(v06, to: outputURL)

        let decoded = try decoder.decode(
            SceneDescriptor.self,
            from: Data(contentsOf: outputURL)
        )
        let effectiveSampling =
            try DescriptorSamplingResolver.resolve(
                descriptor: decoded
            )
        let usedMaterials =
            eastV06MaterialReferences(decoded)
        let missingMaterials =
            usedMaterials.subtracting(materialIDs)
        var decodeFailures: [String] = []
        if decoded.viewDirection != "east" {
            decodeFailures.append("viewDirection")
        }
        if decoded.sourceRevision != eastV06Revision {
            decodeFailures.append("sourceRevision")
        }
        if decoded.productionSelected {
            decodeFailures.append("productionSelected")
        }
        if decoded.building.usesExplicitComponentGeometry != true {
            decodeFailures.append("usesExplicitComponentGeometry")
        }
        if decoded.entrance.pavilionMaterialID != "v05-hall-metal" {
            decodeFailures.append("pavilionMaterialID")
        }
        if !missingMaterials.isEmpty {
            decodeFailures.append(
                "missingMaterials=\(missingMaterials.sorted())"
            )
        }
        if decoded.sampling?.sourceRevisionBinding != eastV06Revision {
            decodeFailures.append("sourceRevisionBinding")
        }
        if effectiveSampling.descriptorSchema != 2 {
            decodeFailures.append("descriptorSchema")
        }
        guard decodeFailures.isEmpty else {
            let blocker: [String: Any] = [
                "schema": 1,
                "task": "PLAY-027",
                "type":
                    "industrial-l02-east-v06-metadata-compatibility-blocker",
                "v05DescriptorSHA256":
                    eastV06V05DescriptorSHA256,
                "v06AttemptDescriptorSHA256":
                    try eastV06SHA256(outputURL),
                "authorizedMutations": [
                    "sourceRevision",
                    "sampling.sourceRevisionBinding",
                    "entrance.pavilionMaterialID",
                    "building.chimney.materialID",
                    "facades[north].materialID",
                    "facades[east].materialID",
                    "facades[south].materialID",
                    "facades[west].materialID",
                ],
                "productionDecoderDryDecodePassed": true,
                "descriptorSamplingResolutionPassed": true,
                "fullMaterialReferenceValidationPassed": false,
                "missingMaterialReferences":
                    missingMaterials.sorted(),
                "missingReferenceLocations": [
                    "v04-process-metal": [
                        "building.chimney.materialID",
                    ],
                    "v04-formed-concrete": [
                        "facades[north].materialID",
                        "facades[south].materialID",
                        "facades[west].materialID",
                    ],
                    "v04-corrugated-hall": [
                        "facades[east].materialID",
                    ],
                ],
                "explicitComponentGeometry": true,
                "rendererSkipsChimneyFacadeAndEntranceMetadata":
                    true,
                "authorizedMutationInsufficient": true,
                "sceneKitProcessCount": 0,
                "metalSnapshotCount": 0,
                "rawPixelCount": 0,
                "normalizerProcessCount": 0,
                "sourceAuthority": false,
                "productionSelected": false,
                "passed": false,
                "disposition":
                    "BLOCKED_PENDING_INTEGRATION_MATERIAL_METADATA_AUTHORITY",
            ]
            try eastV06WriteJSON(
                blocker,
                to: evidenceRoot.appendingPathComponent(
                    "prepixel/MATERIAL-REFERENCE-BLOCKER.json"
                )
            )
            throw IndustrialL2EastV06MetadataRepairError.invalid(
                "V06 production decode, sampling, or material validation failed: "
                    + decodeFailures.joined(separator: ", ")
            )
        }

        var stripped = try eastV06Object(outputURL)
        stripped["sourceRevision"] =
            "east-quality-calibration-art-proof-v05"
        var strippedEntrance =
            stripped["entrance"] as! [String: Any]
        strippedEntrance["pavilionMaterialID"] =
            "v02-painted-steel"
        stripped["entrance"] = strippedEntrance
        var strippedBuilding =
            stripped["building"] as! [String: Any]
        var strippedChimney =
            strippedBuilding["chimney"] as! [String: Any]
        strippedChimney["materialID"] =
            "v04-process-metal"
        strippedBuilding["chimney"] = strippedChimney
        stripped["building"] = strippedBuilding
        var strippedFacades =
            stripped["facades"] as! [[String: Any]]
        for index in strippedFacades.indices {
            let direction =
                strippedFacades[index]["direction"] as! String
            strippedFacades[index]["materialID"] =
                direction == "east"
                    ? "v04-corrugated-hall"
                    : "v04-formed-concrete"
        }
        stripped["facades"] = strippedFacades
        var strippedSampling =
            stripped["sampling"] as! [String: Any]
        strippedSampling["sourceRevisionBinding"] =
            "east-quality-calibration-art-proof-v05"
        stripped["sampling"] = strippedSampling
        guard
            try eastV06CanonicalData(stripped)
                == eastV06CanonicalData(v05)
        else {
            throw IndustrialL2EastV06MetadataRepairError.invalid(
                "V06 differs beyond the authorized compatibility metadata values"
            )
        }

        let v05Consumed =
            try eastV06RenderConsumedPayload(v05)
        let v06Consumed =
            try eastV06RenderConsumedPayload(v06)
        let v05ConsumedData =
            try eastV06CanonicalData(v05Consumed)
        let v06ConsumedData =
            try eastV06CanonicalData(v06Consumed)
        guard v05ConsumedData == v06ConsumedData else {
            throw IndustrialL2EastV06MetadataRepairError.invalid(
                "render-consumed scene input changed"
            )
        }

        let rendererSource =
            try String(
                contentsOf: rendererSourceURL,
                encoding: .utf8
            )
        let explicitComponentGuard =
            "if descriptor.building.usesExplicitComponentGeometry != true"
        guard
            rendererSource.contains(
                explicitComponentGuard
            ),
            rendererSource.components(
                separatedBy: explicitComponentGuard
            ).count - 1 == 2,
            rendererSource.contains(
                "try addChimney(descriptor, to: scene)"
            ),
            rendererSource.contains(
                "for facade in descriptor.facades"
            ),
            rendererSource.contains(
                "try addEntrance(descriptor, to: scene)"
            )
        else {
            throw IndustrialL2EastV06MetadataRepairError.invalid(
                "explicit-component entrance omission source contract drift"
            )
        }

        let inventory = try eastV06Inventory(
            v05EvidenceRoot,
            repositoryRoot: root
        )
        let rawProvenanceURL = v05EvidenceRoot.appendingPathComponent(
            "raw-calibration/diagnostics/east-primary/provenance.json"
        )
        let normalizedRunA = v05EvidenceRoot.appendingPathComponent(
            "normalized-calibration/run-a"
        )
        let normalizedRunB = v05EvidenceRoot.appendingPathComponent(
            "normalized-calibration/run-b"
        )
        let normalizedAInventory = try eastV06Inventory(
            normalizedRunA,
            repositoryRoot: root
        )
        let normalizedBInventory = try eastV06Inventory(
            normalizedRunB,
            repositoryRoot: root
        )
        let linkage: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type":
                "industrial-l02-east-v06-metadata-to-v05-pixel-linkage",
            "v05DescriptorSHA256":
                eastV06V05DescriptorSHA256,
            "v06DescriptorSHA256":
                try eastV06SHA256(outputURL),
            "allowedMetadataMutations": [
                "sourceRevision",
                "sampling.sourceRevisionBinding",
                "entrance.pavilionMaterialID",
                "building.chimney.materialID",
                "facades[north].materialID",
                "facades[east].materialID",
                "facades[south].materialID",
                "facades[west].materialID",
            ],
            "materialCompatibilityMappings": [
                "entrance.pavilionMaterialID":
                    "v02-painted-steel -> v05-hall-metal",
                "building.chimney.materialID":
                    "v04-process-metal -> v05-process-metal",
                "facades[east].materialID":
                    "v04-corrugated-hall -> v05-hall-metal",
                "facades[north|south|west].materialID":
                    "v04-formed-concrete -> v05-admin-concrete",
            ],
            "v05RawSHA256": try eastV06SHA256(rawURL),
            "v05RawProvenanceSHA256":
                try eastV06SHA256(rawProvenanceURL),
            "v05EvidenceFileCount": inventory.count,
            "v05EvidenceInventoryDigestSHA256":
                inventory.digest,
            "normalizedRunAFileCount":
                normalizedAInventory.count,
            "normalizedRunAInventoryDigestSHA256":
                normalizedAInventory.digest,
            "normalizedRunBFileCount":
                normalizedBInventory.count,
            "normalizedRunBInventoryDigestSHA256":
                normalizedBInventory.digest,
            "canonicalGeometrySHA256":
                eastV06CanonicalGeometrySHA256,
            "renderConsumedInputSHA256":
                eastV06SHA256(v05ConsumedData),
            "renderConsumedInputsByteIdentical": true,
            "sceneNodeGeometryMaterialInputsByteIdentical":
                true,
            "explicitComponentGeometry": true,
            "chimneyGeometryOmittedBySceneBuilder": true,
            "facadeGeometryOmittedBySceneBuilder": true,
            "entranceGeometryOmittedBySceneBuilder": true,
            "builderPathCitation": [
                "file":
                    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/OfflineSceneRenderer.swift",
                "chimneyGateLines": "640-642",
                "facadeEntranceGateLines": "644-674",
            ],
            "rendererSourceSHA256":
                try eastV06SHA256(rendererSourceURL),
            "productionDecoderDryDecodePassed": true,
            "descriptorSamplingResolutionPassed": true,
            "materialReferenceCount":
                usedMaterials.count,
            "missingMaterialReferences":
                missingMaterials.sorted(),
            "allMaterialReferencesResolved": true,
            "rerenderRequired": false,
            "rerenderReason":
                "the repaired pavilion, chimney, and facade fields are decode-only metadata on the explicit-component path; scene-node, geometry, material, camera, light, registration, sampling, and compositor inputs are unchanged",
            "sceneKitProcessCount": 0,
            "metalSnapshotCount": 0,
            "rawPixelCount": 0,
            "normalizerProcessCount": 0,
            "sourceAuthority": false,
            "productionSelected": false,
            "passed": true,
        ]
        try eastV06WriteJSON(
            linkage,
            to: evidenceRoot.appendingPathComponent(
                "prepixel/METADATA-PIXEL-LINKAGE.json"
            )
        )
        print(
            "PASS East v06 metadata-only decode/material/scene-input linkage"
        )
    }
}
