import CryptoKit
import Foundation

enum AdvanceIndustrialL2V5Error: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: advance-industrial-l2-v5-descriptors --repository-root <path> --fingerprint <json> --materials <json> --evidence-root <path>"
        case let .invalid(message):
            return message
        }
    }
}

private func argument(_ name: String, in arguments: [String]) throws -> String {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else {
        throw AdvanceIndustrialL2V5Error.arguments
    }
    return arguments[index + 1]
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func relative(_ url: URL, root: URL) -> String {
    let prefix = root.path + "/"
    return url.path.hasPrefix(prefix) ? String(url.path.dropFirst(prefix.count)) : url.path
}

private func jsonData(_ object: Any) throws -> Data {
    var data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    return data
}

private let materialKeys: Set<String> = [
    "materialID",
    "wallMaterialID",
    "trimMaterialID",
    "roofMaterialID",
    "foundationMaterialID",
    "doorMaterialID",
    "surroundMaterialID",
    "pavilionMaterialID",
]

private func geometryOnly(_ value: Any) -> Any {
    if let dictionary = value as? [String: Any] {
        var result: [String: Any] = [:]
        for (key, nested) in dictionary where !materialKeys.contains(key) {
            result[key] = geometryOnly(nested)
        }
        return result
    }
    if let array = value as? [Any] {
        return array.map(geometryOnly)
    }
    return value
}

private func geometryContractPayload(_ object: [String: Any]) throws -> Data {
    let keys = [
        "sceneGeometryID",
        "derivation",
        "registration",
        "camera",
        "light",
        "building",
        "facades",
        "entrance",
        "props",
        "occlusionExclusions",
    ]
    var payload: [String: Any] = [:]
    for key in keys {
        guard let value = object[key] else {
            throw AdvanceIndustrialL2V5Error.invalid("missing geometry contract key \(key)")
        }
        payload[key] = geometryOnly(value)
    }
    return try JSONSerialization.data(
        withJSONObject: payload,
        options: [.sortedKeys, .withoutEscapingSlashes]
    )
}

private func materialForMassBlock(_ id: String) -> String {
    if id.contains("high-assembly-hall") { return "i02-v05-corrugated-northwest" }
    if id.contains("fabrication-annex") { return "i02-v05-brick-side" }
    if id.contains("process-tower") { return "i02-v05-brick-northwest" }
    if id.contains("dual-dock-house") { return "i02-v05-recess-sage" }
    if id.contains("secondary-loading-door") { return "i02-v05-loading-door" }
    if id.contains("frontage-") { return "i02-v05-mechanical" }
    if id.contains("service-apron") { return "i02-v05-foundation" }
    return "i02-v05-corrugated-side"
}

private func materialForTrim(_ id: String, direction: String) -> String {
    if id.contains("annex-datum") { return "slate-charcoal" }
    if id.contains("crane") || id.contains("crown") || id.contains("lane") {
        return direction == "east" || direction == "south"
            ? "i02-v05-hazard-recess"
            : "hazard-yellow"
    }
    return direction == "east" || direction == "south"
        ? "i02-v05-trim-side"
        : "limestone-warm"
}

private func materialForFacade(_ facadeDirection: String, targetDirection: String) -> String {
    if facadeDirection == targetDirection { return "i02-v05-loading-throat" }
    return facadeDirection == "north" || facadeDirection == "west"
        ? "i02-v05-corrugated-northwest"
        : "i02-v05-corrugated-side"
}

private func glazingForFacade(_ facadeDirection: String) -> String {
    facadeDirection == "north" || facadeDirection == "west"
        ? "i02-v05-glazing-northwest"
        : "i02-v05-glazing-side"
}

private func remapMaterials(
    object: inout [String: Any],
    direction: String
) throws -> Set<String> {
    guard
        var building = object["building"] as? [String: Any],
        var chimney = building["chimney"] as? [String: Any],
        var massBlocks = building["massBlocks"] as? [[String: Any]],
        var roofVolumes = building["roofVolumes"] as? [[String: Any]],
        var trimBands = building["trimBands"] as? [[String: Any]],
        var facades = object["facades"] as? [[String: Any]],
        var entrance = object["entrance"] as? [String: Any],
        var props = object["props"] as? [[String: Any]]
    else {
        throw AdvanceIndustrialL2V5Error.invalid("\(direction) authored material surfaces are incomplete")
    }

    building["wallMaterialID"] = "i02-v05-corrugated-northwest"
    building["trimMaterialID"] = "limestone-warm"
    building["roofMaterialID"] = "i02-v05-roof-flat"
    building["foundationMaterialID"] = "i02-v05-foundation"
    chimney["materialID"] = "i02-v05-mechanical"
    building["chimney"] = chimney

    for index in massBlocks.indices {
        guard let id = massBlocks[index]["id"] as? String else {
            throw AdvanceIndustrialL2V5Error.invalid("\(direction) mass block has no id")
        }
        massBlocks[index]["materialID"] = materialForMassBlock(id)
    }
    building["massBlocks"] = massBlocks

    for index in roofVolumes.indices {
        guard
            let id = roofVolumes[index]["id"] as? String,
            let shape = roofVolumes[index]["shape"] as? String
        else {
            throw AdvanceIndustrialL2V5Error.invalid("\(direction) roof volume is incomplete")
        }
        roofVolumes[index]["materialID"] =
            shape == "hip" ? "i02-v05-roof-sawtooth" : "i02-v05-roof-flat"
        roofVolumes[index]["trimMaterialID"] = materialForTrim(id, direction: direction)
    }
    building["roofVolumes"] = roofVolumes

    for index in trimBands.indices {
        guard let id = trimBands[index]["id"] as? String else {
            throw AdvanceIndustrialL2V5Error.invalid("\(direction) trim band has no id")
        }
        trimBands[index]["materialID"] = materialForTrim(id, direction: direction)
    }
    building["trimBands"] = trimBands
    object["building"] = building

    for facadeIndex in facades.indices {
        guard let facadeDirection = facades[facadeIndex]["direction"] as? String else {
            throw AdvanceIndustrialL2V5Error.invalid("\(direction) facade has no direction")
        }
        facades[facadeIndex]["materialID"] = materialForFacade(
            facadeDirection,
            targetDirection: direction
        )
        if var bays = facades[facadeIndex]["windowBays"] as? [[String: Any]] {
            for index in bays.indices {
                bays[index]["materialID"] = glazingForFacade(facadeDirection)
            }
            facades[facadeIndex]["windowBays"] = bays
        }
        if var rhythms = facades[facadeIndex]["windowRhythms"] as? [[String: Any]] {
            for index in rhythms.indices {
                rhythms[index]["materialID"] = glazingForFacade(facadeDirection)
            }
            facades[facadeIndex]["windowRhythms"] = rhythms
        }
    }
    object["facades"] = facades

    entrance["doorMaterialID"] = "i02-v05-loading-door"
    entrance["surroundMaterialID"] =
        direction == "east" || direction == "south"
        ? "i02-v05-trim-side"
        : "limestone-warm"
    entrance["pavilionMaterialID"] =
        direction == "east" || direction == "south"
        ? "i02-v05-hazard-recess"
        : "hazard-yellow"
    object["entrance"] = entrance

    for index in props.indices {
        guard let kind = props[index]["kind"] as? String else {
            throw AdvanceIndustrialL2V5Error.invalid("\(direction) prop has no kind")
        }
        switch kind {
        case "rooftop-hvac":
            props[index]["materialID"] = "rooftop-metal"
        case "exhaust-stack":
            props[index]["materialID"] = "exhaust-dark"
        case "service-tank":
            props[index]["materialID"] = "tank-oxide"
        default:
            props[index]["materialID"] = "slate-charcoal"
        }
    }
    object["props"] = props

    var used = Set<String>()
    func collect(_ value: Any) {
        if let dictionary = value as? [String: Any] {
            for (key, nested) in dictionary {
                if materialKeys.contains(key), let id = nested as? String {
                    used.insert(id)
                }
                collect(nested)
            }
        } else if let array = value as? [Any] {
            array.forEach(collect)
        }
    }
    collect(object)
    return used
}

@main
enum AdvanceIndustrialL2V5DescriptorsMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(fileURLWithPath: try argument("--repository-root", in: arguments))
            .standardizedFileURL
        let fingerprintURL = URL(fileURLWithPath: try argument("--fingerprint", in: arguments))
            .standardizedFileURL
        let materialsURL = URL(fileURLWithPath: try argument("--materials", in: arguments))
            .standardizedFileURL
        let evidenceRoot = URL(fileURLWithPath: try argument("--evidence-root", in: arguments))
            .standardizedFileURL
        let directions = ["north", "east", "south", "west"]
        let expectedV04Hashes = [
            "north": "62bda4794068215ea91419368f10a314a28bfac3808c4f8c68d4fd05aed030c3",
            "east": "08f17a9478d417f5f30d14ec231af02fb4c74a36108ab49ce5dd33940db0b6af",
            "south": "420b658a771ed93d6505afddfbb71a330b020df4271bdba943e2adb504533dd0",
            "west": "444bb2cb1fab124dafb36286beb84f183c00669a6e31dd3eb0178ef068b07e7c",
        ]
        let sceneRoot = root.appendingPathComponent(
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/scenes/industrial_l02/variant-0"
        )
        let materialData = try Data(contentsOf: materialsURL)
        let library = try JSONDecoder().decode(MaterialLibraryDescriptor.self, from: materialData)
        guard
            let materialRoot = try JSONSerialization.jsonObject(
                with: materialData
            ) as? [String: Any],
            let materialObjects = materialRoot["materials"] as? [[String: Any]]
        else {
            throw AdvanceIndustrialL2V5Error.invalid(
                "source-v05 material library JSON is incomplete"
            )
        }
        let materialObjectsByID = Dictionary(
            uniqueKeysWithValues: try materialObjects.map { object in
                guard let id = object["id"] as? String else {
                    throw AdvanceIndustrialL2V5Error.invalid(
                        "source-v05 material role has no id"
                    )
                }
                return (id, object)
            }
        )
        let materialIDs = Set(library.materials.map(\.id))
        guard
            library.libraryID == "industrial-l02-v0-source-v05-authored-constant-materials-v1",
            library.productionSelected == false,
            library.materials.count == 21,
            materialIDs.count == 21,
            library.materials.allSatisfy({ $0.emissionRGBA == nil })
        else {
            throw AdvanceIndustrialL2V5Error.invalid("source-v05 material library contract failed")
        }
        let materialSHA = sha256(materialData)

        let fingerprintData = try Data(contentsOf: fingerprintURL)
        guard
            let fingerprint = try JSONSerialization.jsonObject(with: fingerprintData) as? [String: Any],
            let sampling = fingerprint["descriptorSamplingContract"] as? [String: Any],
            sampling["contractID"] as? String == "play027-deterministic-4x-no-msaa-lanczos-v3",
            sampling["sceneKitAntialiasing"] as? String == "none",
            sampling["sceneKitShadows"] as? String == "disabled",
            sampling["sceneKitLightingMode"] as? String == "authored-constant-v1",
            (sampling["linearOversamplingFactor"] as? NSNumber)?.intValue == 4,
            let lighting = sampling["sceneKitLighting"] as? [String: Any],
            lighting["materialLightingModel"] as? String == "constant",
            lighting["sceneLights"] as? String
                == "disabled-zero-intensity-no-shadow",
            (lighting["materialRoleCount"] as? NSNumber)?.intValue == 21,
            (lighting["sceneLightCount"] as? NSNumber)?.intValue == 2,
            lighting["diagnosticCLIProducesSourceAuthority"] as? Bool == false,
            let fingerprintAuthority = fingerprint["sourceAuthority"] as? String
        else {
            throw AdvanceIndustrialL2V5Error.invalid(
                "fingerprint does not bind authored-constant-v1 production sampling"
            )
        }
        let fingerprintSHA = sha256(fingerprintData)
        let archiveRoot = evidenceRoot.appendingPathComponent("source-v04-descriptors")
        let freezeURL = evidenceRoot.appendingPathComponent(
            "SOURCE-V05-DESCRIPTOR-FREEZE.json"
        )
        try FileManager.default.createDirectory(
            at: archiveRoot,
            withIntermediateDirectories: true
        )

        var records: [[String: Any]] = []
        var descriptorHashes = Set<String>()
        var geometryIDs = Set<String>()
        var geometryHashes = Set<String>()
        var allUsedMaterialIDs = Set<String>()

        for direction in directions {
            let sceneURL = sceneRoot
                .appendingPathComponent(direction)
                .appendingPathComponent("scene.json")
            let archiveURL = archiveRoot.appendingPathComponent(
                "\(direction)-source-v04.json"
            )
            let currentData = try Data(contentsOf: sceneURL)
            let currentSHA = sha256(currentData)
            let originalData: Data
            if currentSHA == expectedV04Hashes[direction] {
                originalData = currentData
            } else if FileManager.default.fileExists(atPath: archiveURL.path) {
                originalData = try Data(contentsOf: archiveURL)
            } else {
                throw AdvanceIndustrialL2V5Error.invalid(
                    "\(direction) has neither source-v04 authority nor its archive"
                )
            }
            let originalSHA = sha256(originalData)
            guard originalSHA == expectedV04Hashes[direction] else {
                throw AdvanceIndustrialL2V5Error.invalid(
                    "\(direction) source-v04 descriptor hash changed"
                )
            }
            guard
                var object = try JSONSerialization.jsonObject(with: originalData) as? [String: Any],
                object["schema"] as? Int == 2,
                object["logicalBuildingID"] as? String == "industrial_l02",
                object["sourceRevision"] as? String == "source-v04",
                object["viewDirection"] as? String == direction,
                object["authoredIndependently"] as? Bool == true,
                object["productionSelected"] as? Bool == false,
                let derivation = object["derivation"] as? [String: Any],
                derivation["sourceKind"] as? String == "independent-scene-description",
                derivation["siblingSource"] is NSNull,
                derivation["mirror"] as? Bool == false,
                (derivation["rotationDegrees"] as? NSNumber)?.doubleValue == 0,
                derivation["transform"] as? String == "none",
                var descriptorSampling = object["sampling"] as? [String: Any],
                descriptorSampling["sourceRevisionBinding"] as? String == "source-v04",
                descriptorSampling["sceneKitShadows"] as? String == "disabled"
            else {
                throw AdvanceIndustrialL2V5Error.invalid(
                    "\(direction) is not frozen source-v04 authority"
                )
            }
            let geometryBefore = try geometryContractPayload(object)
            if FileManager.default.fileExists(atPath: archiveURL.path) {
                guard try Data(contentsOf: archiveURL) == originalData else {
                    throw AdvanceIndustrialL2V5Error.invalid(
                        "\(direction) source-v04 archive differs from authority"
                    )
                }
            } else {
                try originalData.write(to: archiveURL, options: .atomic)
            }

            object["sourceRevision"] = "source-v05"
            descriptorSampling["sourceRevisionBinding"] = "source-v05"
            descriptorSampling["sceneKitLightingMode"] = "authored-constant-v1"
            object["sampling"] = descriptorSampling
            object["materialLibrary"] = [
                "role": "industrial-l02-source-v05-authored-constant-material-roles",
                "file": relative(materialsURL, root: root),
                "sha256": materialSHA,
            ]
            object["toolchainFingerprint"] = [
                "role": "frozen-schema-2-v3-authored-constant-offline-host-and-frameworks",
                "file": relative(fingerprintURL, root: root),
                "sha256": fingerprintSHA,
            ]
            let usedMaterials = try remapMaterials(object: &object, direction: direction)
            let missingMaterials = usedMaterials.subtracting(materialIDs)
            guard missingMaterials.isEmpty else {
                throw AdvanceIndustrialL2V5Error.invalid(
                    "\(direction) references missing materials \(missingMaterials.sorted())"
                )
            }
            allUsedMaterialIDs.formUnion(usedMaterials)

            let geometryAfter = try geometryContractPayload(object)
            guard geometryBefore == geometryAfter else {
                throw AdvanceIndustrialL2V5Error.invalid(
                    "\(direction) geometry/camera/registration/light contract changed"
                )
            }
            let v05Data = try jsonData(object)
            let descriptor = try JSONDecoder().decode(SceneDescriptor.self, from: v05Data)
            let resolved = try DescriptorSamplingResolver.resolve(descriptor: descriptor)
            guard
                resolved.sceneKitLightingMode == "authored-constant-v1",
                resolved.sceneKitShadows == "disabled",
                resolved.sceneKitAntialiasing == "none",
                resolved.linearOversamplingFactor == 4,
                resolved.downsampleFilter == "CILanczosScaleTransform",
                resolved.downsampleScale == 0.25,
                resolved.postQuantizationCanonicalizer?.version == 3,
                descriptor.productionSelected == false
            else {
                throw AdvanceIndustrialL2V5Error.invalid(
                    "\(direction) source-v05 sampling resolution failed"
                )
            }
            try v05Data.write(to: sceneURL, options: .atomic)
            let descriptorSHA = sha256(v05Data)
            let geometrySHA = sha256(geometryAfter)
            guard descriptorHashes.insert(descriptorSHA).inserted else {
                throw AdvanceIndustrialL2V5Error.invalid(
                    "\(direction) descriptor aliases a sibling"
                )
            }
            guard geometryIDs.insert(descriptor.sceneGeometryID).inserted else {
                throw AdvanceIndustrialL2V5Error.invalid(
                    "\(direction) geometry id aliases a sibling"
                )
            }
            guard geometryHashes.insert(geometrySHA).inserted else {
                throw AdvanceIndustrialL2V5Error.invalid(
                    "\(direction) geometry payload aliases a sibling"
                )
            }
            records.append([
                "direction": direction,
                "sourceV04DescriptorFile": relative(archiveURL, root: root),
                "sourceV04DescriptorSHA256": originalSHA,
                "sourceV05DescriptorFile": relative(sceneURL, root: root),
                "sourceV05DescriptorSHA256": descriptorSHA,
                "sceneGeometryID": descriptor.sceneGeometryID,
                "geometryContractSHA256": geometrySHA,
                "geometryCameraRegistrationLightChanged": false,
                "usedMaterialIDs": usedMaterials.sorted(),
                "usedMaterialRoleCount": usedMaterials.count,
                "sceneKitLightingMode": resolved.sceneKitLightingMode,
                "sceneKitAntialiasing": resolved.sceneKitAntialiasing,
                "sceneKitShadows": resolved.sceneKitShadows,
                "linearOversamplingFactor": resolved.linearOversamplingFactor,
                "downsampleFilter": resolved.downsampleFilter,
                "downsampleScale": resolved.downsampleScale,
                "postQuantizationCanonicalizerVersion":
                    resolved.postQuantizationCanonicalizer?.version ?? 0,
                "productionSelected": false,
            ])
        }
        guard
            records.count == 4,
            descriptorHashes.count == 4,
            geometryIDs.count == 4,
            geometryHashes.count == 4,
            allUsedMaterialIDs == materialIDs
        else {
            throw AdvanceIndustrialL2V5Error.invalid(
                "source-v05 uniqueness/material coverage gate failed; unused \(materialIDs.subtracting(allUsedMaterialIDs).sorted())"
            )
        }

        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "logicalBuildingID": "industrial_l02",
            "variantID": "variant-0",
            "sourceRevision": "source-v05",
            "sourceAuthority": fingerprintAuthority,
            "contract": "play027-deterministic-4x-no-msaa-lanczos-v3",
            "sceneKitLightingMode": "authored-constant-v1",
            "sceneKitMaterialLightingModel": "constant",
            "sceneKitLights": "zero-intensity-no-shadow",
            "sceneKitAntialiasing": "none",
            "sceneKitShadows": "disabled",
            "linearOversamplingFactor": 4,
            "softwareLanczosScale": 0.25,
            "authoredContactShadowPreserved": true,
            "diagnosticCLIHasSourceAuthority": false,
            "fingerprintFile": relative(fingerprintURL, root: root),
            "fingerprintSHA256": fingerprintSHA,
            "materialLibraryFile": relative(materialsURL, root: root),
            "materialLibrarySHA256": materialSHA,
            "materialRoleHashes": Dictionary(
                uniqueKeysWithValues: try materialIDs.sorted().map { id in
                    guard let object = materialObjectsByID[id] else {
                        throw AdvanceIndustrialL2V5Error.invalid(
                            "missing exact material object \(id)"
                        )
                    }
                    let encoded = try JSONSerialization.data(
                        withJSONObject: object,
                        options: [.sortedKeys, .withoutEscapingSlashes]
                    )
                    return (id, sha256(encoded))
                }
            ),
            "materialRoleHashEncoding":
                "sorted exact JSON material object including explicit nulls",
            "materialRoleCount": materialIDs.count,
            "allMaterialRolesUsedAcrossFourScenes": true,
            "directions": records,
            "descriptorCount": records.count,
            "uniqueDescriptorHashCount": descriptorHashes.count,
            "uniqueGeometryIDCount": geometryIDs.count,
            "uniqueGeometryContractHashCount": geometryHashes.count,
            "geometryChanged": false,
            "cameraChanged": false,
            "registrationChanged": false,
            "lightContractChanged": false,
            "materialsChanged": true,
            "rawPixelsCreated": false,
            "normalizationPerformed": false,
            "productionSelected": false,
            "passed": true,
        ]
        try jsonData(report).write(
            to: freezeURL,
            options: .atomic
        )
    }
}
