import CryptoKit
import Foundation

enum IndustrialL3V6SamplingResolverError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return """
            usage: validate-industrial-l3-v6-sampling-resolver \
              --repository-root <path> --report <json>
            """
        case let .invalid(message):
            return message
        }
    }
}

private struct V6Binding {
    let direction: String
    let descriptorPath: String
    let descriptorSHA256: String
    let geometryID: String
    let materialPath: String
    let materialSHA256: String
}

private let bindings = [
    V6Binding(
        direction: "north",
        descriptorPath:
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "art-proof/industrial-l03-cohesion-source-v06-v01/scenes/"
            + "industrial_l03/variant-0/north/scene.json",
        descriptorSHA256:
            "adc73af1704c067d75f62b818d9a6ee7da6c7ff87637356552ef72393f8c77a9",
        geometryID: "industrial-l03-north-v06-open-loading-court",
        materialPath:
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "art-proof/industrial-l03-cohesion-source-v06-v01/materials/"
            + "industrial-l03-source-v06-north.json",
        materialSHA256:
            "2a9c9fa964f6135207b7ab4bbdea37f343ebd7ac0e14cc0356ece643616d3fc8"
    ),
    V6Binding(
        direction: "west",
        descriptorPath:
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "art-proof/industrial-l03-cohesion-source-v06-v01/scenes/"
            + "industrial_l03/variant-0/west/scene.json",
        descriptorSHA256:
            "d4affd0773c557056cf15b56db66dfb76736658a995df68cdd86a48b84178f4f",
        geometryID: "industrial-l03-west-v06-open-loading-court",
        materialPath:
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "art-proof/industrial-l03-cohesion-source-v06-v01/materials/"
            + "industrial-l03-source-v06-west.json",
        materialSHA256:
            "928c5dc9963b3a67e5e4cd9e48033ec11efbc8d8aa9f32eb45f0730b8e2e3faf"
    ),
]

private func argument(_ name: String, in arguments: [String]) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL3V6SamplingResolverError.arguments
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

private func object(_ data: Data) throws -> [String: Any] {
    guard
        let value = try JSONSerialization.jsonObject(with: data)
            as? [String: Any]
    else {
        throw IndustrialL3V6SamplingResolverError.invalid(
            "descriptor must be a JSON object"
        )
    }
    return value
}

private func effectiveRecord(
    _ contract: EffectiveSamplingContract
) -> [String: Any] {
    [
        "contractID": contract.contractID,
        "descriptorSchema": contract.descriptorSchema,
        "sceneKitAntialiasing": contract.sceneKitAntialiasing,
        "sceneKitShadows": contract.sceneKitShadows,
        "sceneKitLightingMode": contract.sceneKitLightingMode,
        "linearOversamplingFactor": contract.linearOversamplingFactor,
        "downsampleFilter": contract.downsampleFilter,
        "downsampleScale": contract.downsampleScale,
        "downsampleAspectRatio": contract.downsampleAspectRatio,
        "ciUseSoftwareRenderer": contract.ciUseSoftwareRenderer,
        "ciCacheIntermediates": contract.ciCacheIntermediates,
        "ciWorkingColorSpace": contract.ciWorkingColorSpace,
        "ciOutputColorSpace": contract.ciOutputColorSpace,
        "quantizerID": contract.quantizerID,
        "quantizerStep": contract.quantizerStep,
        "quantizerMidpointOffset": contract.quantizerMidpointOffset,
        "chromaBypassRGBA": contract.chromaBypassRGBA,
        "canonicalizerID": contract.canonicalizerID,
        "canonicalizerEncoder": contract.canonicalizerEncoder,
        "canonicalizerPostEncoder":
            contract.canonicalizerPostEncoder,
        "canonicalizerFormat": contract.canonicalizerFormat,
        "purpose": contract.purpose,
    ]
}

private func assertContract(
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
        throw IndustrialL3V6SamplingResolverError.invalid(
            "\(direction) did not resolve to the exact v3 contract"
        )
    }
}

private func mutatedDescriptor(
    source: Data,
    mutation: String,
    other: V6Binding
) throws -> SceneDescriptor {
    var root = try object(source)
    guard
        var sampling = root["sampling"] as? [String: Any],
        var material = root["materialLibrary"] as? [String: Any]
    else {
        throw IndustrialL3V6SamplingResolverError.invalid(
            "source-v06 binding blocks missing"
        )
    }
    switch mutation {
    case "direction":
        root["viewDirection"] = "northeast"
    case "east":
        root["viewDirection"] = "east"
        root["sceneGeometryID"] =
            "industrial-l03-east-v06-open-loading-court"
    case "south":
        root["viewDirection"] = "south"
        root["sceneGeometryID"] =
            "industrial-l03-south-v06-open-loading-court"
    case "variant":
        root["variantID"] = "variant-1"
    case "revision":
        root["sourceRevision"] = "source-v07"
        sampling["sourceRevisionBinding"] = "source-v07"
    case "binding":
        sampling["sourceRevisionBinding"] = "source-v05"
    case "geometry":
        root["sceneGeometryID"] =
            "industrial-l03-north-v06-wrong-geometry"
    case "purpose":
        sampling["purpose"] = "diagnostic-regression"
    case "contract":
        sampling["contractID"] =
            "play027-deterministic-4x-no-msaa-lanczos-v2"
    case "lighting":
        sampling["sceneKitLightingMode"] = "lambert-scene-lights"
    case "shadows":
        sampling["sceneKitShadows"] = "current"
    case "antialiasing":
        sampling["sceneKitAntialiasing"] = "multisampling4X"
    case "material-path":
        material["file"] = other.materialPath
    case "material-hash":
        material["sha256"] = other.materialSHA256
    case "swapped-library":
        material["file"] = other.materialPath
        material["sha256"] = other.materialSHA256
    default:
        throw IndustrialL3V6SamplingResolverError.invalid(
            "unknown mutation \(mutation)"
        )
    }
    root["sampling"] = sampling
    root["materialLibrary"] = material
    let data = try JSONSerialization.data(
        withJSONObject: root,
        options: [.sortedKeys, .withoutEscapingSlashes]
    )
    return try JSONDecoder().decode(SceneDescriptor.self, from: data)
}

private func failure(
    _ descriptor: SceneDescriptor,
    label: String
) throws -> String {
    do {
        _ = try DescriptorSamplingResolver.resolve(descriptor: descriptor)
        throw IndustrialL3V6SamplingResolverError.invalid(
            "\(label) unexpectedly resolved"
        )
    } catch let error as SamplingContractError {
        return error.description
    }
}

private func write(_ object: Any, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw IndustrialL3V6SamplingResolverError.invalid(
            "report output must be absent"
        )
    }
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try jsonData(object).write(to: url, options: .atomic)
}

@main
enum ValidateIndustrialL3V6SamplingResolverMain {
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

        var positives: [[String: Any]] = []
        var descriptorData: [String: Data] = [:]
        for binding in bindings {
            let sceneURL = root.appendingPathComponent(
                binding.descriptorPath
            )
            let materialURL = root.appendingPathComponent(
                binding.materialPath
            )
            let sceneData = try Data(contentsOf: sceneURL)
            let materialData = try Data(contentsOf: materialURL)
            guard sha256(sceneData) == binding.descriptorSHA256 else {
                throw IndustrialL3V6SamplingResolverError.invalid(
                    "\(binding.direction) descriptor hash drift"
                )
            }
            guard sha256(materialData) == binding.materialSHA256 else {
                throw IndustrialL3V6SamplingResolverError.invalid(
                    "\(binding.direction) material hash drift"
                )
            }
            let descriptor = try JSONDecoder().decode(
                SceneDescriptor.self,
                from: sceneData
            )
            guard
                descriptor.logicalBuildingID == "industrial_l03",
                descriptor.variantID == "variant-0",
                descriptor.sourceRevision == "source-v06",
                descriptor.viewDirection == binding.direction,
                descriptor.sceneGeometryID == binding.geometryID,
                descriptor.materialLibrary.file == binding.materialPath,
                descriptor.materialLibrary.sha256
                    == binding.materialSHA256,
                descriptor.sampling?.sourceRevisionBinding == "source-v06"
            else {
                throw IndustrialL3V6SamplingResolverError.invalid(
                    "\(binding.direction) identity binding drift"
                )
            }
            let contract = try DescriptorSamplingResolver.resolve(
                descriptor: descriptor
            )
            try assertContract(contract, direction: binding.direction)
            let record = effectiveRecord(contract)
            positives.append([
                "direction": binding.direction,
                "descriptorFile": binding.descriptorPath,
                "descriptorSHA256": binding.descriptorSHA256,
                "sceneGeometryID": binding.geometryID,
                "materialFile": binding.materialPath,
                "materialSHA256": binding.materialSHA256,
                "effectiveContractRecord": record,
                "effectiveContractRecordSHA256":
                    sha256(try jsonData(record)),
                "passed": true,
            ])
            descriptorData[binding.direction] = sceneData
        }

        guard
            let northData = descriptorData["north"],
            let westBinding = bindings.first(where: {
                $0.direction == "west"
            })
        else {
            throw IndustrialL3V6SamplingResolverError.invalid(
                "North/West binding source missing"
            )
        }
        let mutations = [
            "direction",
            "variant",
            "revision",
            "binding",
            "geometry",
            "purpose",
            "contract",
            "lighting",
            "shadows",
            "antialiasing",
            "material-path",
            "material-hash",
            "swapped-library",
            "east",
            "south",
        ]
        let negatives = try mutations.map { mutation in
            [
                "mutation": mutation,
                "failedClosed": true,
                "resolverError": try failure(
                    mutatedDescriptor(
                        source: northData,
                        mutation: mutation,
                        other: westBinding
                    ),
                    label: mutation
                ),
            ]
        }
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "scope":
                "hash-and-material-bound Industrial L3 source-v06 "
                + "North/West resolver",
            "positiveCount": positives.count,
            "positiveCases": positives,
            "negativeCount": negatives.count,
            "negativeCases": negatives,
            "swappedLibrariesRejected": true,
            "sourceV06EastRejected": true,
            "sourceV06SouthRejected": true,
            "descriptorMutationCount": 0,
            "materialMutationCount": 0,
            "rawRenderProcesses": 0,
            "sceneKitProcesses": 0,
            "metalProcesses": 0,
            "normalizerProcesses": 0,
            "sourceAuthority": false,
            "familyAuthority": false,
            "productionSelected": false,
            "passed":
                positives.count == 2
                && negatives.count == mutations.count,
        ]
        try write(report, to: reportURL)
    }
}
