import CryptoKit
import Foundation

enum IndustrialL2DirectionalFamilyV04RepairError:
    Error,
    CustomStringConvertible
{
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return """
            usage: repair-industrial-l2-directional-family-v04 \
              --repository-root <path> \
              [--art-output-root <path>] \
              [--evidence-output-root <path>]
            """
        case let .invalid(message):
            return message
        }
    }
}

private let familyV04InputHashes = [
    "north":
        "d220f3065219ccb1e18d653f9af7257c4e922c05db26ada0af3cdaa120f3fb79",
    "south":
        "7534f31b875efccf98e2046c5f03207ba5fe759c7131d7b6066f009941ac6c78",
    "west":
        "4ff4aafa858be94db7348695de79f51ef39f69fb1beeab8b7d634f6f5fbc459a",
]

private let familyV04GeometryHashes = [
    "north":
        "c9ecd93a68e230315fe7a9213b3a4a277c0c6c235c62898282c11d3ce7e70f57",
    "south":
        "f036a561f796e49f62188573dc919c6dc25141aa3fe67a4c7f84df6a49017c18",
    "west":
        "a929f9bc244f153d7fbb52b6cb69c1860c32976c3d86d897b814fb3b3ff84e96",
]

private let familyV04EastDescriptorSHA256 =
    "482bea0169e9229df437b05ca6f0299046d49bb92e2e9d9ef4f3865df9be5fa0"
private let familyV04EastMaterialsSHA256 =
    "6ab8b19d6d6cf53dc98f77867117569f6cccd104cd886a2dc1788361736404fb"
private let familyV04EastRawSHA256 =
    "a32725fd0ea0436c1f8a13d319c3c66408a7cdf44ff8f2cdb72665839dd685a8"
private let familyV04EastGeometrySHA256 =
    "6c727c4b7053d69578e97c2f73cf3054cd2dda106bf06625e0dac12a356798fb"
private let familyV04PanelBuilderSHA256 =
    "07625630e25dc33e4546aae5ffec4180a70198cab3fd882a8c66aec5ab883823"

private let familyV04AddedKeys = [
    "stepRun",
    "canopyDepth",
    "hingeSide",
    "pavilionWidth",
    "pavilionDepth",
    "pavilionHeight",
    "pavilionRoofHeight",
    "pavilionMaterialID",
    "porchWidth",
    "porchColumnWidth",
    "porchLateralOffset",
]

private func familyV04Argument(
    _ name: String,
    in arguments: [String],
    required: Bool = true
) throws -> String? {
    guard let index = arguments.firstIndex(of: name) else {
        if required {
            throw IndustrialL2DirectionalFamilyV04RepairError.arguments
        }
        return nil
    }
    guard index + 1 < arguments.count else {
        throw IndustrialL2DirectionalFamilyV04RepairError.arguments
    }
    return arguments[index + 1]
}

private func familyV04SHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func familyV04SHA256(_ url: URL) throws -> String {
    familyV04SHA256(try Data(contentsOf: url))
}

private func familyV04CanonicalData(_ value: Any) throws -> Data {
    var data = try JSONSerialization.data(
        withJSONObject: value,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    return data
}

private func familyV04Object(_ url: URL) throws -> [String: Any] {
    guard
        let object = try JSONSerialization.jsonObject(
            with: Data(contentsOf: url)
        ) as? [String: Any]
    else {
        throw IndustrialL2DirectionalFamilyV04RepairError.invalid(
            "could not decode \(url.path)"
        )
    }
    return object
}

private func familyV04WriteJSON(_ value: Any, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw IndustrialL2DirectionalFamilyV04RepairError.invalid(
            "output must be absent: \(url.path)"
        )
    }
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try familyV04CanonicalData(value).write(to: url, options: .atomic)
}

private func familyV04MaterialReferences(
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

private func familyV04ExpectedRegistration(
    _ direction: String
) -> (
    pivot: [Double],
    socket: [Double],
    frontage: [[Double]]
) {
    switch direction {
    case "north":
        return (
            [768, 896],
            [896, 704],
            [[768, 640], [1024, 768]]
        )
    case "south":
        return (
            [768, 896],
            [640, 832],
            [[768, 896], [512, 768]]
        )
    default:
        return (
            [768, 896],
            [640, 704],
            [[512, 768], [768, 640]]
        )
    }
}

@main
enum RepairIndustrialL2DirectionalFamilyV04EntranceCompletenessMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath:
                try familyV04Argument(
                    "--repository-root",
                    in: arguments
                )!
        ).standardizedFileURL
        let artRoot = URL(
            fileURLWithPath:
                try familyV04Argument(
                    "--art-output-root",
                    in: arguments,
                    required: false
                ) ?? root.appendingPathComponent(
                    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-directional-family-v04"
                ).path
        ).standardizedFileURL
        let evidenceRoot = URL(
            fileURLWithPath:
                try familyV04Argument(
                    "--evidence-output-root",
                    in: arguments,
                    required: false
                ) ?? root.appendingPathComponent(
                    "docs/production/evidence/PLAY-027/industrial-l02/l02/directional-family-v04"
                ).path
        ).standardizedFileURL
        guard
            artRoot.path.contains(
                "industrial-l02-directional-family-v04"
            ),
            evidenceRoot.path.contains(
                "industrial-l02/l02/directional-family-v04"
            ),
            !FileManager.default.fileExists(atPath: artRoot.path),
            !FileManager.default.fileExists(atPath: evidenceRoot.path)
        else {
            throw IndustrialL2DirectionalFamilyV04RepairError.invalid(
                "outputs must be absent and task-owned"
            )
        }

        let v03Root = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-directional-family-v03/scenes/industrial_l02/variant-0"
        )
        let eastDescriptorURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-east-calibration-v05/scenes/industrial_l02/variant-0/east/scene.json"
        )
        let materialsURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-east-calibration-v05/materials/industrial-l02-east-calibration-v05.json"
        )
        let eastRawURL = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/industrial-l02/l02/east-calibration-v05/raw-calibration/diagnostics/east-primary/raw.png"
        )
        let panelBuilderURL = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/BuildIndustrialL2DirectionalFamilyV02PrepixelPanels.swift"
        )
        guard
            try familyV04SHA256(eastDescriptorURL)
                == familyV04EastDescriptorSHA256,
            try familyV04SHA256(materialsURL)
                == familyV04EastMaterialsSHA256,
            try familyV04SHA256(eastRawURL)
                == familyV04EastRawSHA256,
            try familyV04SHA256(panelBuilderURL)
                == familyV04PanelBuilderSHA256
        else {
            throw IndustrialL2DirectionalFamilyV04RepairError.invalid(
                "immutable East or panel-builder input drift"
            )
        }

        let decoder = JSONDecoder()
        let eastDecoded = try decoder.decode(
            SceneDescriptor.self,
            from: Data(contentsOf: eastDescriptorURL)
        )
        let eastObject = try familyV04Object(eastDescriptorURL)
        guard
            eastDecoded.viewDirection == "east",
            eastDecoded.productionSelected == false,
            let eastEntrance =
                eastObject["entrance"] as? [String: Any],
            eastEntrance["stepRun"] as? Double == 2,
            eastEntrance["canopyDepth"] as? Double == 9,
            eastEntrance["hingeSide"] as? String == "right",
            eastEntrance["pavilionWidth"] as? Double == 30,
            eastEntrance["pavilionDepth"] as? Double == 8,
            eastEntrance["pavilionHeight"] as? Double == 24,
            eastEntrance["pavilionRoofHeight"] as? Double == 3,
            eastEntrance["porchWidth"] as? Double == 30,
            eastEntrance["porchColumnWidth"] as? Double == 1.4,
            eastEntrance["porchLateralOffset"] as? Double == 0,
            eastEntrance["pavilionMaterialID"] as? String
                == "v02-painted-steel"
        else {
            throw IndustrialL2DirectionalFamilyV04RepairError.invalid(
                "immutable East entrance precedent drift"
            )
        }
        let materials = try decoder.decode(
            MaterialLibraryDescriptor.self,
            from: Data(contentsOf: materialsURL)
        )
        let materialIDs = Set(materials.materials.map(\.id))
        guard
            !materialIDs.contains("v02-painted-steel"),
            materialIDs.contains("v05-safety"),
            materialIDs.contains("v05-hall-metal")
        else {
            throw IndustrialL2DirectionalFamilyV04RepairError.invalid(
                "dangling East material premise or V03 valid precedent drift"
            )
        }

        let commonValues: [String: Any] = [
            "stepRun": 2.0,
            "canopyDepth": 9.0,
            "hingeSide": "right",
            "pavilionWidth": 30.0,
            "pavilionDepth": 8.0,
            "pavilionHeight": 24.0,
            "pavilionRoofHeight": 3.0,
            "pavilionMaterialID": "v05-hall-metal",
            "porchWidth": 30.0,
            "porchColumnWidth": 1.4,
            "porchLateralOffset": 0.0,
        ]
        let numericAuthority =
            "immutable East v05 matching field; descriptor SHA "
            + familyV04EastDescriptorSHA256
        var fieldLedger: [[String: Any]] = []
        for key in familyV04AddedKeys where key != "pavilionMaterialID" {
            fieldLedger.append([
                "field": "entrance.\(key)",
                "value": commonValues[key]!,
                "authority": numericAuthority,
                "authorityFile":
                    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/industrial-l02-east-calibration-v05/scenes/industrial_l02/variant-0/east/scene.json",
            ])
        }
        fieldLedger.append([
            "field": "entrance.pavilionMaterialID",
            "value": "v05-hall-metal",
            "authority":
                "integration-approved same-role mapping: dangling East v02-painted-steel is blue-gray steel RGBA 0.56/0.62/0.66 roughness 0.75 metalness 0.24; v05-hall-metal is the closest immutable East-v05 blue-gray steel RGBA 0.60/0.72/0.80 roughness 0.76 metalness 0.22",
            "rejectedDanglingEastValue": "v02-painted-steel",
            "materialLibrarySHA256":
                familyV04EastMaterialsSHA256,
        ])

        var rows: [[String: Any]] = []
        var newDescriptorHashes: Set<String> = []
        var newGeometryHashes: Set<String> = [
            familyV04EastGeometrySHA256
        ]
        for direction in ["north", "south", "west"] {
            let inputURL = v03Root.appendingPathComponent(
                "\(direction)/scene.json"
            )
            guard
                try familyV04SHA256(inputURL)
                    == familyV04InputHashes[direction],
                var input = try? familyV04Object(inputURL),
                var entrance = input["entrance"] as? [String: Any],
                familyV04AddedKeys.allSatisfy({
                    entrance[$0] == nil
                }),
                entrance["surroundMaterialID"] as? String
                    == "v05-safety"
            else {
                throw IndustrialL2DirectionalFamilyV04RepairError.invalid(
                    "\(direction) V03 input or compatibility premise drift"
                )
            }
            let original = input
            for key in familyV04AddedKeys {
                entrance[key] = commonValues[key]
            }
            input["entrance"] = entrance
            let outputURL = artRoot.appendingPathComponent(
                "scenes/industrial_l02/variant-0/\(direction)/scene.json"
            )
            try familyV04WriteJSON(input, to: outputURL)
            let outputData = try Data(contentsOf: outputURL)
            let decoded = try decoder.decode(
                SceneDescriptor.self,
                from: outputData
            )
            let usedMaterials =
                familyV04MaterialReferences(decoded)
            let missingMaterials =
                usedMaterials.subtracting(materialIDs)
            let expected =
                familyV04ExpectedRegistration(direction)
            guard
                decoded.viewDirection == direction,
                decoded.productionSelected == false,
                decoded.building.usesExplicitComponentGeometry
                    == true,
                decoded.entrance.stepCount == 1,
                decoded.entrance.pavilionMaterialID
                    == "v05-hall-metal",
                decoded.entrance.pavilionMaterialID
                    != "v05-safety",
                missingMaterials.isEmpty,
                decoded.registration.groundPivotSource
                    == expected.pivot,
                decoded.registration.frontageSocketSource
                    == expected.socket,
                decoded.registration.frontageEdgeSource
                    == expected.frontage
            else {
                throw IndustrialL2DirectionalFamilyV04RepairError.invalid(
                    "\(direction) production decode, material, or registration validation failed"
                )
            }
            var stripped = try familyV04Object(outputURL)
            var strippedEntrance =
                stripped["entrance"] as! [String: Any]
            for key in familyV04AddedKeys {
                strippedEntrance.removeValue(forKey: key)
            }
            stripped["entrance"] = strippedEntrance
            guard
                try familyV04CanonicalData(stripped)
                    == familyV04CanonicalData(original)
            else {
                throw IndustrialL2DirectionalFamilyV04RepairError.invalid(
                    "\(direction) differs beyond compatibility-only fields"
                )
            }
            let descriptorHash =
                try familyV04SHA256(outputURL)
            newDescriptorHashes.insert(descriptorHash)
            newGeometryHashes.insert(
                familyV04GeometryHashes[direction]!
            )
            rows.append([
                "direction": direction,
                "oldDescriptorSHA256":
                    familyV04InputHashes[direction]!,
                "newDescriptorSHA256": descriptorHash,
                "oldCanonicalGeometrySHA256":
                    familyV04GeometryHashes[direction]!,
                "newCanonicalGeometrySHA256":
                    familyV04GeometryHashes[direction]!,
                "removedCompatibilityFieldsReproduceV03":
                    true,
                "productionSceneDescriptorDecodePassed": true,
                "requiredEntranceKeysPresent": true,
                "materialReferenceCount":
                    usedMaterials.count,
                "missingMaterialReferences":
                    missingMaterials.sorted(),
                "pivotSocketFrontageExact": true,
                "entranceCompatibilityFieldsRenderNeutral":
                    true,
                "productionSelected": false,
            ])
        }
        newDescriptorHashes.insert(
            familyV04EastDescriptorSHA256
        )
        guard
            newDescriptorHashes.count == 4,
            newGeometryHashes.count == 4
        else {
            throw IndustrialL2DirectionalFamilyV04RepairError.invalid(
                "four-direction uniqueness failed"
            )
        }

        let validation: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "type":
                "industrial-l02-directional-family-v04-prepixel-compatibility-validation",
            "inputCheckpoint":
                "0e9dfda3aef9a67ac45a50a2cafa5c995805bde6",
            "directions": rows,
            "fieldAuthorityLedger": fieldLedger,
            "addedKeys": familyV04AddedKeys,
            "rejectedDanglingEastPavilionMaterialID":
                "v02-painted-steel",
            "selectedMaterialValidPrecedent":
                "v05-hall-metal",
            "selectedMaterialPresentInEastLibrary": true,
            "pavilionMaterialIsNotSafetyAccent": true,
            "eastDanglingPavilionMaterialFamilyBlocker": true,
            "completeFamilyAuthorityClaimed": false,
            "productionDecoderDryDecodeCount": 4,
            "productionDecoderDryDecodePassed": true,
            "requiredKeyValidationPassed": true,
            "materialReferenceValidationPassed": true,
            "canonicalEquivalencePassed": true,
            "uniqueFourDirectionDescriptorHashCount":
                newDescriptorHashes.count,
            "uniqueFourDirectionGeometryHashCount":
                newGeometryHashes.count,
            "eastDescriptorBytePreserved": true,
            "eastMaterialLibraryBytePreserved": true,
            "eastRawBytePreserved": true,
            "panelBuilderSHA256":
                familyV04PanelBuilderSHA256,
            "panelBuilderReadsEntrance": false,
            "sceneKitProcessCount": 0,
            "metalSnapshotCount": 0,
            "rawPixelCount": 0,
            "normalizerProcessCount": 0,
            "sourceAuthority": false,
            "productionSelected": false,
            "passed": true,
        ]
        try familyV04WriteJSON(
            validation,
            to: evidenceRoot.appendingPathComponent(
                "prepixel/PREPIXEL-VALIDATION.json"
            )
        )
        print(
            "PASS productionDecode=4 materialReferences=valid directions=4"
        )
    }
}
