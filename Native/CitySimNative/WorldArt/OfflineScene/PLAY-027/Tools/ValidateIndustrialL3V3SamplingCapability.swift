import CryptoKit
import Foundation

enum IndustrialL3V3SamplingValidationError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: validate-industrial-l3-v3-sampling-capability --repository-root <path> --report <json>"
        case let .invalid(message):
            return message
        }
    }
}

private let l3V3FrozenDescriptors = [
    (
        "north",
        "11b559a3b2ba4c679a22cd063f94cec56c06c4f46c9c93af2832d31eb06b6bf9"
    ),
    (
        "east",
        "1a4687b3ac6db8492ee8030f44dc04d99db163d460c5b923fb628a72d8279448"
    ),
    (
        "south",
        "e0d286c55bfd79527faf87b3c5c75b725ec5dea4394b2d3e1af13b57642f9126"
    ),
    (
        "west",
        "46cfb19f041bb3303cf4fd5d84a84e111c5892122512859202bfe2b59410bfaf"
    ),
]

private func v3Argument(
    _ name: String,
    in arguments: [String]
) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL3V3SamplingValidationError.arguments
    }
    return arguments[index + 1]
}

private func v3SHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func v3Object(_ data: Data) throws -> [String: Any] {
    guard
        let object = try JSONSerialization.jsonObject(with: data)
            as? [String: Any]
    else {
        throw IndustrialL3V3SamplingValidationError.invalid(
            "descriptor is not a JSON object"
        )
    }
    return object
}

private func v3JSON(_ object: Any) throws -> Data {
    var data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    return data
}

private func v3MutatedDescriptor(
    source: [String: Any],
    mutation: String
) throws -> SceneDescriptor {
    var object = source
    guard
        var sampling = object["sampling"] as? [String: Any],
        var preLanczos =
            sampling["preLanczosCanonicalizer"] as? [String: Any]
    else {
        throw IndustrialL3V3SamplingValidationError.invalid(
            "sampling or pre-Lanczos block missing"
        )
    }
    switch mutation {
    case "logicalBuildingID":
        object["logicalBuildingID"] = "industrial_l04"
    case "variantID":
        object["variantID"] = "variant-1"
    case "sourceRevision":
        object["sourceRevision"] = "source-v04"
        sampling["sourceRevisionBinding"] = "source-v04"
    case "viewDirection":
        object["viewDirection"] = "northeast"
    case "purpose":
        sampling["purpose"] = "diagnostic-regression"
    case "contractID":
        sampling["contractID"] = "play027-invalid-contract"
    case "preLanczos.missing":
        sampling.removeValue(forKey: "preLanczosCanonicalizer")
    case "preLanczos.algorithm":
        preLanczos["algorithm"] = "invalid"
    case "preLanczos.version":
        preLanczos["version"] = 2
    case "preLanczos.quantizationStep":
        preLanczos["quantizationStep"] = 31
    case "preLanczos.midpointOffset":
        preLanczos["midpointOffset"] = 7
    case "preLanczos.chromaBypassRGBA":
        preLanczos["chromaBypassRGBA"] = [254, 0, 255, 255]
    case "preLanczos.channels":
        preLanczos["channels"] = "rgba"
    case "preLanczos.opaquePixelPolicy":
        preLanczos["opaquePixelPolicy"] = "invalid"
    case "preLanczos.transparentPixelPolicy":
        preLanczos["transparentPixelPolicy"] = "invalid"
    case "preLanczos.partialAlphaPolicy":
        preLanczos["partialAlphaPolicy"] = "allow"
    case "preLanczos.preservesAlpha":
        preLanczos["preservesAlpha"] = false
    case "preLanczos.preservesChroma":
        preLanczos["preservesChroma"] = false
    case "preLanczos.immutableSourceBuffer":
        preLanczos["immutableSourceBuffer"] = false
    case "preLanczos.crossRunState":
        preLanczos["crossRunState"] = "process"
    default:
        throw IndustrialL3V3SamplingValidationError.invalid(
            "unknown mutation \(mutation)"
        )
    }
    if mutation != "preLanczos.missing" {
        sampling["preLanczosCanonicalizer"] = preLanczos
    }
    object["sampling"] = sampling
    let data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.sortedKeys, .withoutEscapingSlashes]
    )
    return try JSONDecoder().decode(SceneDescriptor.self, from: data)
}

private func v3RequiresFailure(
    _ descriptor: SceneDescriptor,
    label: String
) throws -> String {
    do {
        _ = try DescriptorSamplingResolver.resolve(descriptor: descriptor)
        throw IndustrialL3V3SamplingValidationError.invalid(
            "\(label) unexpectedly resolved"
        )
    } catch let error as SamplingContractError {
        return error.description
    }
}

@main
enum ValidateIndustrialL3V3SamplingCapabilityMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(
            fileURLWithPath: try v3Argument(
                "--repository-root",
                in: arguments
            )
        ).standardizedFileURL
        let reportURL = URL(
            fileURLWithPath: try v3Argument("--report", in: arguments)
        ).standardizedFileURL
        let descriptorRoot =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/"
            + "industrial-l03-directional-family-v03/scenes/"
            + "industrial_l03/variant-0"
        var positives: [[String: Any]] = []
        var mutationSource: [String: Any]?
        for (direction, expectedHash) in l3V3FrozenDescriptors {
            let relative = "\(descriptorRoot)/\(direction)/scene.json"
            let data = try Data(
                contentsOf: root.appendingPathComponent(relative)
            )
            guard v3SHA256(data) == expectedHash else {
                throw IndustrialL3V3SamplingValidationError.invalid(
                    "\(direction) descriptor hash drift"
                )
            }
            let object = try v3Object(data)
            let descriptor = try JSONDecoder().decode(
                SceneDescriptor.self,
                from: data
            )
            let resolved = try DescriptorSamplingResolver.resolve(
                descriptor: descriptor
            )
            guard
                descriptor.logicalBuildingID == "industrial_l03",
                descriptor.variantID == "variant-0",
                descriptor.sourceRevision == "source-v03",
                descriptor.viewDirection == direction,
                resolved.contractID
                    == DescriptorSamplingResolver.schema2ContractV3ID,
                resolved.sceneKitAntialiasing == "none",
                resolved.sceneKitShadows == "disabled",
                resolved.sceneKitLightingMode
                    == "authored-constant-v1",
                resolved.linearOversamplingFactor == 4,
                resolved.downsampleScale == 0.25,
                resolved.preLanczosCanonicalizer?.algorithm
                    == "rgb-step32-midpoint8-preserve-alpha-chroma-v1",
                resolved.preLanczosCanonicalizer?.version == 1,
                resolved.postQuantizationCanonicalizer?.version == 3,
                resolved.purpose == "source-authority"
            else {
                throw IndustrialL3V3SamplingValidationError.invalid(
                    "\(direction) exact v3 contract mismatch"
                )
            }
            if mutationSource == nil {
                mutationSource = object
            }
            positives.append([
                "direction": direction,
                "descriptorFile": relative,
                "descriptorSHA256": expectedHash,
                "resolvedContractID": resolved.contractID,
                "preLanczosAlgorithm":
                    resolved.preLanczosCanonicalizer?.algorithm as Any,
                "passed": true,
            ])
        }
        guard let mutationSource else {
            throw IndustrialL3V3SamplingValidationError.invalid(
                "no mutation source"
            )
        }
        let mutations = [
            "logicalBuildingID",
            "variantID",
            "sourceRevision",
            "viewDirection",
            "purpose",
            "contractID",
            "preLanczos.missing",
            "preLanczos.algorithm",
            "preLanczos.version",
            "preLanczos.quantizationStep",
            "preLanczos.midpointOffset",
            "preLanczos.chromaBypassRGBA",
            "preLanczos.channels",
            "preLanczos.opaquePixelPolicy",
            "preLanczos.transparentPixelPolicy",
            "preLanczos.partialAlphaPolicy",
            "preLanczos.preservesAlpha",
            "preLanczos.preservesChroma",
            "preLanczos.immutableSourceBuffer",
            "preLanczos.crossRunState",
        ]
        var negatives: [[String: Any]] = []
        for mutation in mutations {
            let error = try v3RequiresFailure(
                v3MutatedDescriptor(
                    source: mutationSource,
                    mutation: mutation
                ),
                label: mutation
            )
            negatives.append([
                "mutation": mutation,
                "failedClosed": true,
                "resolverError": error,
            ])
        }
        let rendererSourceRelative =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "Sources/RendererArchitecture.swift"
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "scope":
                "Industrial L3 variant-0 source-v03 N/E/S/W exact "
                + "pre-Lanczos schema-2 v3 resolver capability",
            "positiveCases": positives,
            "negativeCases": negatives,
            "positiveCount": positives.count,
            "negativeCount": negatives.count,
            "rendererArchitectureSHA256": v3SHA256(
                try Data(
                    contentsOf:
                        root.appendingPathComponent(rendererSourceRelative)
                )
            ),
            "descriptorMutationCount": 0,
            "materialMutationCount": 0,
            "productionSelected": false,
            "sourceAuthority": false,
            "passed":
                positives.count == 4
                && negatives.count == mutations.count,
        ]
        try FileManager.default.createDirectory(
            at: reportURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try v3JSON(report).write(to: reportURL, options: .atomic)
    }
}
