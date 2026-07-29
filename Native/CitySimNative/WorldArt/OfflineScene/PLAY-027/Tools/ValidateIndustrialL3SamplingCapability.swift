import CryptoKit
import Foundation

enum IndustrialL3SamplingCapabilityError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: validate-industrial-l3-sampling-capability --repository-root <path> --report <json>"
        case let .invalid(message):
            return message
        }
    }
}

private struct FrozenIndustrialL3Descriptor {
    let direction: String
    let relativePath: String
    let sha256: String
}

private let frozenIndustrialL3Descriptors = [
    FrozenIndustrialL3Descriptor(
        direction: "north",
        relativePath:
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "art-proof/industrial-l03-directional-family-v02/scenes/"
            + "industrial_l03/variant-0/north/scene.json",
        sha256:
            "78803712a2b4118abef6ff90119444b1c4093f5cb442348f3cdb9b3e4bf1fe51"
    ),
    FrozenIndustrialL3Descriptor(
        direction: "east",
        relativePath:
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "art-proof/industrial-l03-directional-family-v02/scenes/"
            + "industrial_l03/variant-0/east/scene.json",
        sha256:
            "dbe0dd260d28d848864d4194826f5147ec91314cf75b95bff9349bbfe466342c"
    ),
    FrozenIndustrialL3Descriptor(
        direction: "south",
        relativePath:
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "art-proof/industrial-l03-directional-family-v02/scenes/"
            + "industrial_l03/variant-0/south/scene.json",
        sha256:
            "1e548d4694bea47b36e9aca1a97e901917ea92742fd6366f53a4e92bfcba1b2b"
    ),
    FrozenIndustrialL3Descriptor(
        direction: "west",
        relativePath:
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "art-proof/industrial-l03-directional-family-v02/scenes/"
            + "industrial_l03/variant-0/west/scene.json",
        sha256:
            "bc0812eb16008bb0a544873fb3d24c4b01c470c405b4f6051a36a400c68856ce"
    ),
]

private func argument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL3SamplingCapabilityError.arguments
    }
    return arguments[index + 1]
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func jsonData(_ object: Any) throws -> Data {
    var data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    return data
}

private func jsonObject(_ data: Data) throws -> [String: Any] {
    guard
        let object = try JSONSerialization.jsonObject(with: data)
            as? [String: Any]
    else {
        throw IndustrialL3SamplingCapabilityError.invalid(
            "descriptor is not a JSON object"
        )
    }
    return object
}

private func assertFrozenContract(
    _ contract: EffectiveSamplingContract,
    direction: String
) throws {
    guard
        contract.contractID
            == DescriptorSamplingResolver.schema2ContractV3ID,
        contract.descriptorSchema == 2,
        contract.sceneKitAntialiasing == "none",
        contract.sceneKitShadows == "disabled",
        contract.sceneKitLightingMode == "authored-constant-v1",
        contract.linearOversamplingFactor == 4,
        contract.downsampleFilter == "CILanczosScaleTransform",
        contract.downsampleScale == 0.25,
        contract.downsampleAspectRatio == 1,
        contract.ciUseSoftwareRenderer,
        !contract.ciCacheIntermediates,
        contract.ciWorkingColorSpace == "extended-srgb",
        contract.ciOutputColorSpace == "srgb",
        contract.quantizerID == "step32-midpoint-offset8-v1",
        contract.quantizerStep == 32,
        contract.quantizerMidpointOffset == 8,
        contract.chromaBypassRGBA == [255, 0, 255, 255],
        contract.canonicalizerID == "imageio-sips-png-v1",
        contract.canonicalizerEncoder == "ImageIO",
        contract.canonicalizerPostEncoder == "/usr/bin/sips",
        contract.canonicalizerFormat == "png",
        contract.preLanczosCanonicalizer == nil,
        contract.postQuantizationCanonicalizer?.version == 3,
        contract.postQuantizationCanonicalizer?
            .boundaryAssist?.version == 1,
        contract.purpose == "source-authority"
    else {
        throw IndustrialL3SamplingCapabilityError.invalid(
            "\(direction) did not resolve to the exact schema-2 v3 contract"
        )
    }
}

private func mutatedDescriptor(
    from source: [String: Any],
    mutation: String
) throws -> SceneDescriptor {
    var object = source
    guard var sampling = object["sampling"] as? [String: Any] else {
        throw IndustrialL3SamplingCapabilityError.invalid(
            "sampling block missing"
        )
    }
    switch mutation {
    case "logicalBuildingID":
        object["logicalBuildingID"] = "industrial_l04"
    case "sourceRevision":
        object["sourceRevision"] = "source-v03"
        sampling["sourceRevisionBinding"] = "source-v03"
    case "purpose":
        sampling["purpose"] = "diagnostic-regression"
    case "viewDirection":
        object["viewDirection"] = "northeast"
    case "sceneKitShadows":
        sampling["sceneKitShadows"] = "current"
    case "sceneKitLightingMode":
        sampling["sceneKitLightingMode"] = "lambert-scene-lights"
    case "contractID":
        sampling["contractID"] = "play027-invalid-contract"
    default:
        throw IndustrialL3SamplingCapabilityError.invalid(
            "unknown mutation \(mutation)"
        )
    }
    object["sampling"] = sampling
    let data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.sortedKeys, .withoutEscapingSlashes]
    )
    return try JSONDecoder().decode(SceneDescriptor.self, from: data)
}

private func requireResolverFailure(
    _ descriptor: SceneDescriptor,
    label: String
) throws -> String {
    do {
        _ = try DescriptorSamplingResolver.resolve(descriptor: descriptor)
        throw IndustrialL3SamplingCapabilityError.invalid(
            "\(label) unexpectedly resolved"
        )
    } catch let error as SamplingContractError {
        return error.description
    }
}

@main
enum ValidateIndustrialL3SamplingCapabilityMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try argument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let reportURL = URL(
            fileURLWithPath: try argument("--report", in: arguments)
        ).standardizedFileURL
        let rendererSourceRelative =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "Sources/RendererArchitecture.swift"
        let rendererSourceData = try Data(
            contentsOf: root.appendingPathComponent(rendererSourceRelative)
        )

        var positiveRecords: [[String: Any]] = []
        var firstObject: [String: Any]?
        for frozen in frozenIndustrialL3Descriptors {
            let url = root.appendingPathComponent(frozen.relativePath)
            let data = try Data(contentsOf: url)
            guard sha256(data) == frozen.sha256 else {
                throw IndustrialL3SamplingCapabilityError.invalid(
                    "\(frozen.direction) descriptor hash drift"
                )
            }
            let object = try jsonObject(data)
            let descriptor = try JSONDecoder().decode(
                SceneDescriptor.self,
                from: data
            )
            guard
                descriptor.logicalBuildingID == "industrial_l03",
                descriptor.sourceRevision == "source-v02",
                descriptor.viewDirection == frozen.direction,
                descriptor.sampling?.purpose == "source-authority"
            else {
                throw IndustrialL3SamplingCapabilityError.invalid(
                    "\(frozen.direction) frozen identity mismatch"
                )
            }
            let contract = try DescriptorSamplingResolver.resolve(
                descriptor: descriptor
            )
            try assertFrozenContract(
                contract,
                direction: frozen.direction
            )
            if firstObject == nil {
                firstObject = object
            }
            positiveRecords.append([
                "direction": frozen.direction,
                "descriptorFile": frozen.relativePath,
                "descriptorSHA256": frozen.sha256,
                "contractID": contract.contractID,
                "sceneKitAntialiasing": contract.sceneKitAntialiasing,
                "sceneKitShadows": contract.sceneKitShadows,
                "sceneKitLightingMode": contract.sceneKitLightingMode,
                "linearOversamplingFactor":
                    contract.linearOversamplingFactor,
                "downsampleFilter": contract.downsampleFilter,
                "downsampleScale": contract.downsampleScale,
                "postQuantizationCanonicalizerVersion":
                    contract.postQuantizationCanonicalizer?.version as Any,
                "boundaryAssistVersion":
                    contract.postQuantizationCanonicalizer?
                        .boundaryAssist?.version as Any,
                "passed": true,
            ])
        }

        guard let mutationSource = firstObject else {
            throw IndustrialL3SamplingCapabilityError.invalid(
                "no frozen descriptor loaded"
            )
        }
        let mutations = [
            "logicalBuildingID",
            "sourceRevision",
            "purpose",
            "viewDirection",
            "sceneKitShadows",
            "sceneKitLightingMode",
            "contractID",
        ]
        var negativeRecords: [[String: Any]] = []
        for mutation in mutations {
            let failure = try requireResolverFailure(
                mutatedDescriptor(
                    from: mutationSource,
                    mutation: mutation
                ),
                label: mutation
            )
            negativeRecords.append([
                "mutation": mutation,
                "failedClosed": true,
                "resolverError": failure,
            ])
        }

        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "scope":
                "Industrial L3 source-v02 N/E/S/W schema-2 v3 "
                + "source-authority resolver capability",
            "rendererArchitectureFile": rendererSourceRelative,
            "rendererArchitectureBeforeSHA256":
                "e0943590ee01f8518fbd3a230fa126e607b6aa130c6fcc422e250eb9467b76af",
            "rendererArchitectureAfterSHA256":
                sha256(rendererSourceData),
            "positiveCount": positiveRecords.count,
            "negativeCount": negativeRecords.count,
            "positiveCases": positiveRecords,
            "negativeCases": negativeRecords,
            "descriptorMutationCount": 0,
            "productionSelected": false,
            "passed":
                positiveRecords.count == 4
                && negativeRecords.count == mutations.count,
        ]
        try FileManager.default.createDirectory(
            at: reportURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try jsonData(report).write(to: reportURL, options: .atomic)
    }
}
