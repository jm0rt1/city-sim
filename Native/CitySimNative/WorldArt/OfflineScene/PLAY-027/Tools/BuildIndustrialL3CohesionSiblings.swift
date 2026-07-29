import CryptoKit
import Foundation

enum IndustrialL3CohesionSiblingsError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return """
            usage: build-industrial-l3-cohesion-siblings \
              --repository-root <path> --output-root <path>
            """
        case let .invalid(message):
            return message
        }
    }
}

private struct DirectionInput {
    let direction: String
    let descriptorSHA256: String
}

private let directions = [
    DirectionInput(
        direction: "north",
        descriptorSHA256:
            "78803712a2b4118abef6ff90119444b1c4093f5cb442348f3cdb9b3e4bf1fe51"
    ),
    DirectionInput(
        direction: "south",
        descriptorSHA256:
            "1e548d4694bea47b36e9aca1a97e901917ea92742fd6366f53a4e92bfcba1b2b"
    ),
    DirectionInput(
        direction: "west",
        descriptorSHA256:
            "bc0812eb16008bb0a544873fb3d24c4b01c470c405b4f6051a36a400c68856ce"
    ),
]

private let baseSceneRoot =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
    + "art-proof/industrial-l03-directional-family-v02/scenes/"
    + "industrial_l03/variant-0"
private let acceptedCohesionMaterialRelative =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
    + "art-proof/industrial-l03-cohesion-east-v01/materials/"
    + "industrial-l03-cohesion-east-v01.json"
private let acceptedCohesionMaterialSHA256 =
    "f39bbf5914ba15f90f100bfed5ac65e537b5a6a62d677be82698ac89cf982b65"
private let acceptedEastDescriptorRelative =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
    + "art-proof/industrial-l03-cohesion-east-v01/scenes/"
    + "industrial_l03/variant-0/east/scene.json"
private let acceptedEastDescriptorSHA256 =
    "1e5c69a03a6298f64f4d4d13bb0f523690729b82d5565343f40aaa8278aa3b6d"
private let outputSceneRoot =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
    + "art-proof/industrial-l03-cohesion-siblings-v01/scenes/"
    + "industrial_l03/variant-0"
private let evidenceRelative =
    "docs/production/evidence/PLAY-027/industrial-l03/l03/"
    + "cohesion-a0-family-v01/prepixel"

private let materialMap = [
    "l3-recess": "l3c-deep-recess",
    "l3-dock-door": "l3c-heavy-dock-door",
    "l3-hall-blue": "l3c-weathered-blue-steel",
    "l3-hall-light": "l3c-weathered-blue-steel-light",
    "l3-plinth": "l3c-warm-rusticated-plinth",
    "l3-admin-concrete": "l3c-warm-formed-concrete",
    "l3-foundation": "l3c-charcoal-foundation",
    "l3-apron": "l3c-warm-scored-apron",
    "l3-roof": "l3c-weathered-roof-membrane",
    "l3-roof-dark": "l3c-heavy-roof-outline",
    "l3-glazing": "l3c-smoky-industrial-glazing",
    "l3-warm-glazing": "l3c-warm-control-glazing",
    "l3-process-metal": "l3c-oxidized-process-metal",
    "l3-duct-metal": "l3c-dull-duct-metal",
    "l3-dark-steel": "l3c-charcoal-outline-steel",
    "l3-light-trim": "l3c-warm-trim",
    "l3-safety": "l3c-restrained-safety",
    "l3-tank-oxide": "l3c-oxidized-tank",
    "l3-pipe": "l3c-dull-pipe",
]

private func argument(_ name: String, in arguments: [String]) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL3CohesionSiblingsError.arguments
    }
    return arguments[index + 1]
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func sha256(_ url: URL) throws -> String {
    sha256(try Data(contentsOf: url))
}

private func jsonData(_ object: Any) throws -> Data {
    var data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    return data
}

private func jsonObject(_ data: Data) throws -> Any {
    try JSONSerialization.jsonObject(with: data)
}

private func write(_ data: Data, to url: URL) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: url, options: .atomic)
}

private func transformedValue(_ value: Any, reverse: Bool = false) throws -> Any {
    let replacements = reverse
        ? Dictionary(uniqueKeysWithValues: materialMap.map { ($0.value, $0.key) })
        : materialMap
    if let dictionary = value as? [String: Any] {
        var result: [String: Any] = [:]
        for (key, child) in dictionary {
            if (key == "materialID" || key.hasSuffix("MaterialID")),
                let materialID = child as? String
            {
                guard let replacement = replacements[materialID] else {
                    throw IndustrialL3CohesionSiblingsError.invalid(
                        "unmapped material reference \(materialID)"
                    )
                }
                result[key] = replacement
            } else {
                result[key] = try transformedValue(child, reverse: reverse)
            }
        }
        return result
    }
    if let array = value as? [Any] {
        return try array.map { try transformedValue($0, reverse: reverse) }
    }
    return value
}

private func materialReferenceIDs(in value: Any) -> Set<String> {
    if let dictionary = value as? [String: Any] {
        var result = Set<String>()
        for (key, child) in dictionary {
            if (key == "materialID" || key.hasSuffix("MaterialID")),
                let materialID = child as? String
            {
                result.insert(materialID)
            }
            result.formUnion(materialReferenceIDs(in: child))
        }
        return result
    }
    if let array = value as? [Any] {
        return array.reduce(into: Set<String>()) {
            $0.formUnion(materialReferenceIDs(in: $1))
        }
    }
    return []
}

private func canonicalGeometryValue(_ value: Any) throws -> Any {
    guard var dictionary = value as? [String: Any] else {
        return value
    }
    dictionary["sourceRevision"] = "source-v02"
    if var sampling = dictionary["sampling"] as? [String: Any] {
        sampling["sourceRevisionBinding"] = "source-v02"
        dictionary["sampling"] = sampling
    }
    return try transformedValue(dictionary, reverse: true)
}

private func requireResolverFailure(
    _ object: [String: Any],
    label: String
) throws -> String {
    do {
        let data = try jsonData(object)
        let descriptor = try JSONDecoder().decode(
            SceneDescriptor.self,
            from: data
        )
        _ = try DescriptorSamplingResolver.resolve(descriptor: descriptor)
    } catch {
        return "pass: \(label): \(error)"
    }
    throw IndustrialL3CohesionSiblingsError.invalid(
        "resolver did not fail closed for \(label)"
    )
}

@main
struct BuildIndustrialL3CohesionSiblings {
    static func main() throws {
        let arguments = CommandLine.arguments
        let repositoryRoot = URL(
            fileURLWithPath: try argument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let outputRoot = URL(
            fileURLWithPath: try argument("--output-root", in: arguments)
        ).standardizedFileURL
        let materialURL =
            repositoryRoot.appendingPathComponent(
                acceptedCohesionMaterialRelative
            )
        let eastDescriptorURL =
            repositoryRoot.appendingPathComponent(
                acceptedEastDescriptorRelative
            )
        guard
            try sha256(materialURL) == acceptedCohesionMaterialSHA256,
            try sha256(eastDescriptorURL) == acceptedEastDescriptorSHA256
        else {
            throw IndustrialL3CohesionSiblingsError.invalid(
                "accepted East cohesion calibration hash drift"
            )
        }
        let materialObject = try jsonObject(Data(contentsOf: materialURL))
        let materialIDs = Set(
            ((materialObject as? [String: Any])?["materials"]
                as? [[String: Any]] ?? []).compactMap { $0["id"] as? String }
        )
        let evidenceRoot =
            outputRoot.appendingPathComponent(evidenceRelative)
        guard
            !FileManager.default.fileExists(atPath: evidenceRoot.path)
        else {
            throw IndustrialL3CohesionSiblingsError.invalid(
                "pre-pixel evidence output must be absent"
            )
        }

        var directionRecords: [[String: Any]] = []
        var geometryIDs = Set<String>()
        var descriptorHashes = Set<String>()
        var geometryHashes = Set<String>()
        var transformedObjects: [String: [String: Any]] = [:]

        for input in directions {
            let baseRelative =
                "\(baseSceneRoot)/\(input.direction)/scene.json"
            let baseURL =
                repositoryRoot.appendingPathComponent(baseRelative)
            guard try sha256(baseURL) == input.descriptorSHA256 else {
                throw IndustrialL3CohesionSiblingsError.invalid(
                    "\(input.direction) accepted descriptor hash drift"
                )
            }
            let baseData = try Data(contentsOf: baseURL)
            let baseObject = try jsonObject(baseData)
            guard var transformed =
                try transformedValue(baseObject) as? [String: Any]
            else {
                throw IndustrialL3CohesionSiblingsError.invalid(
                    "\(input.direction) descriptor is not a JSON object"
                )
            }
            transformed["sourceRevision"] = "source-v04"
            guard var sampling = transformed["sampling"] as? [String: Any] else {
                throw IndustrialL3CohesionSiblingsError.invalid(
                    "\(input.direction) sampling block missing"
                )
            }
            sampling["sourceRevisionBinding"] = "source-v04"
            transformed["sampling"] = sampling

            let baseCanonical = try jsonData(baseObject)
            let restoredCanonical = try jsonData(
                canonicalGeometryValue(transformed)
            )
            guard baseCanonical == restoredCanonical else {
                throw IndustrialL3CohesionSiblingsError.invalid(
                    "\(input.direction) non-authorized descriptor drift"
                )
            }
            let data = try jsonData(transformed)
            let descriptor = try JSONDecoder().decode(
                SceneDescriptor.self,
                from: data
            )
            let effective = try DescriptorSamplingResolver.resolve(
                descriptor: descriptor
            )
            guard
                descriptor.logicalBuildingID == "industrial_l03",
                descriptor.variantID == "variant-0",
                descriptor.viewDirection == input.direction,
                descriptor.sourceRevision == "source-v04",
                descriptor.authoredIndependently,
                descriptor.registration.orientationTransform == "none",
                effective.contractID
                    == DescriptorSamplingResolver.schema2ContractV3ID,
                effective.sceneKitAntialiasing == "none",
                effective.sceneKitShadows == "disabled",
                effective.sceneKitLightingMode == "authored-constant-v1",
                effective.preLanczosCanonicalizer == nil
            else {
                throw IndustrialL3CohesionSiblingsError.invalid(
                    "\(input.direction) effective contract mismatch"
                )
            }
            let referenced = materialReferenceIDs(in: transformed)
            guard referenced.isSubset(of: materialIDs) else {
                throw IndustrialL3CohesionSiblingsError.invalid(
                    "\(input.direction) unresolved cohesion material reference"
                )
            }
            let outputRelative =
                "\(outputSceneRoot)/\(input.direction)/scene.json"
            let outputURL =
                outputRoot.appendingPathComponent(outputRelative)
            guard
                !FileManager.default.fileExists(atPath: outputURL.path)
            else {
                throw IndustrialL3CohesionSiblingsError.invalid(
                    "\(input.direction) output descriptor must be absent"
                )
            }
            try write(data, to: outputURL)

            let descriptorSHA = sha256(data)
            let geometrySHA = sha256(baseCanonical)
            let geometryID = descriptor.sceneGeometryID
            geometryIDs.insert(geometryID)
            descriptorHashes.insert(descriptorSHA)
            geometryHashes.insert(geometrySHA)
            transformedObjects[input.direction] = transformed
            directionRecords.append([
                "direction": input.direction,
                "acceptedDescriptorFile": baseRelative,
                "acceptedDescriptorSHA256": input.descriptorSHA256,
                "cohesionDescriptorFile": outputRelative,
                "cohesionDescriptorSHA256": descriptorSHA,
                "canonicalAcceptedDescriptorSHA256": geometrySHA,
                "canonicalGeometryRegistrationIdentity": true,
                "sceneGeometryID": geometryID,
                "authoredIndependently": true,
                "orientationTransform": "none",
                "materialReferenceCount": referenced.count,
                "materialReferencesResolved": true,
                "samplingContract": effective.contractID,
            ])
        }

        guard
            geometryIDs.count == directions.count,
            descriptorHashes.count == directions.count,
            geometryHashes.count == directions.count
        else {
            throw IndustrialL3CohesionSiblingsError.invalid(
                "sibling descriptor or geometry identity alias"
            )
        }

        guard var northWrongDirection = transformedObjects["north"] else {
            throw IndustrialL3CohesionSiblingsError.invalid(
                "north transformed descriptor missing"
            )
        }
        northWrongDirection["viewDirection"] = "up"
        var northWrongRevision = transformedObjects["north"]!
        northWrongRevision["sourceRevision"] = "source-v05"
        var wrongRevisionSampling =
            northWrongRevision["sampling"] as! [String: Any]
        wrongRevisionSampling["sourceRevisionBinding"] = "source-v05"
        northWrongRevision["sampling"] = wrongRevisionSampling
        var northWrongPurpose = transformedObjects["north"]!
        var wrongPurposeSampling =
            northWrongPurpose["sampling"] as! [String: Any]
        wrongPurposeSampling["purpose"] = "diagnostic-regression"
        northWrongPurpose["sampling"] = wrongPurposeSampling
        var northWrongLogicalID = transformedObjects["north"]!
        northWrongLogicalID["logicalBuildingID"] = "industrial_l04"
        let failClosed = [
            "invalidDirection": try requireResolverFailure(
                northWrongDirection,
                label: "invalid direction"
            ),
            "wrongRevision": try requireResolverFailure(
                northWrongRevision,
                label: "wrong revision"
            ),
            "wrongPurpose": try requireResolverFailure(
                northWrongPurpose,
                label: "wrong purpose"
            ),
            "wrongLogicalBuildingID": try requireResolverFailure(
                northWrongLogicalID,
                label: "wrong logical building ID"
            ),
        ]

        let eastDescriptor = try JSONDecoder().decode(
            SceneDescriptor.self,
            from: Data(contentsOf: eastDescriptorURL)
        )
        let eastEffective = try DescriptorSamplingResolver.resolve(
            descriptor: eastDescriptor
        )
        guard
            eastEffective.contractID
                == DescriptorSamplingResolver.schema2ContractV3ID,
            eastEffective.sceneKitAntialiasing == "none",
            eastEffective.sceneKitShadows == "disabled",
            eastEffective.sceneKitLightingMode == "authored-constant-v1",
            eastEffective.preLanczosCanonicalizer == nil
        else {
            throw IndustrialL3CohesionSiblingsError.invalid(
                "accepted East effective sampling contract drift"
            )
        }

        let builderRelative =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/"
            + "BuildIndustrialL3CohesionSiblings.swift"
        let resolverRelative =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/"
            + "RendererArchitecture.swift"
        let validation: [String: Any] = [
            "task": "PLAY-027",
            "program": "Wave-011-A0",
            "batch": "industrial-l03-cohesion-siblings-v01",
            "authority":
                "pre-pixel-descriptor-boundary-not-source-family-or-production-acceptance",
            "sourceAuthority": false,
            "familyAuthority": false,
            "productionSelected": false,
            "sceneKitProcesses": 0,
            "normalizerProcesses": 0,
            "imageGenCalls": 0,
            "directions": directionRecords,
            "uniqueDescriptorHashes": descriptorHashes.count,
            "uniqueCanonicalGeometryHashes": geometryHashes.count,
            "uniqueSceneGeometryIDs": geometryIDs.count,
            "acceptedEastDescriptorFile": acceptedEastDescriptorRelative,
            "acceptedEastDescriptorSHA256": acceptedEastDescriptorSHA256,
            "acceptedEastBytePreserved": true,
            "acceptedCohesionMaterialLibraryFile":
                acceptedCohesionMaterialRelative,
            "acceptedCohesionMaterialLibrarySHA256":
                acceptedCohesionMaterialSHA256,
            "acceptedCohesionMaterialLibraryBytePreserved": true,
            "materialMapping": materialMap,
            "resolverFailClosed": failClosed,
            "acceptedEastSamplingReproduction": "pass",
            "postProcessTint": false,
            "recolorOnlyAlias": false,
            "mirrorOrRotation": false,
            "builderSourceFile": builderRelative,
            "builderSourceSHA256": try sha256(
                repositoryRoot.appendingPathComponent(builderRelative)
            ),
            "resolverSourceFile": resolverRelative,
            "resolverSourceSHA256": try sha256(
                repositoryRoot.appendingPathComponent(resolverRelative)
            ),
            "nextGate":
                "one governed source-v04 primary each for north, south, and west; stop on first raw technical or visual failure",
        ]
        try write(
            try jsonData(validation),
            to: evidenceRoot.appendingPathComponent(
                "PREPIXEL-VALIDATION.json"
            )
        )
        let review = """
        # Industrial L3 cohesion siblings — pre-pixel review boundary

        This checkpoint extends the independently accepted East source-v04
        material/value/outline calibration to North, South, and West while
        preserving each sibling's accepted source-v02 authored geometry,
        camera, footprint, pivot, road-facing socket, frontage, contact shadow,
        and registration byte-for-value.

        Each descriptor remains independently authored with
        `orientationTransform: none`; no sibling is mirrored, rotated, cloned,
        post-process tinted, or accepted as a recolor-only alias. The only
        authorized changes are `source-v04` revision binding and the exact
        accepted East cohesion material-role references. The accepted East
        descriptor and material library remain byte-preserved.

        Source authority, family authority, and `productionSelected` remain
        false. The next gate consumes exactly one governed primary for each of
        North, South, and West, followed by two deterministic normalizations
        per direction and one four-direction independent-review packet.
        """
        try write(
            Data((review + "\n").utf8),
            to: evidenceRoot.appendingPathComponent(
                "INDEPENDENT-REVIEW-REQUEST.md"
            )
        )
    }
}
