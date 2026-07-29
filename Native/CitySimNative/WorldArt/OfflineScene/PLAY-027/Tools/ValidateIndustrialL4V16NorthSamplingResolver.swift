import CryptoKit
import Foundation

enum IndustrialL4V16NorthSamplingResolverError:
    Error, CustomStringConvertible
{
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return """
            usage: validate-industrial-l4-v16-north-sampling-resolver \
              --repository-root <path> --report <json>
            """
        case let .invalid(message):
            return message
        }
    }
}

private let descriptorPath =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
    + "art-proof/industrial-l04-crucible-gantry-v16-north-prepixel/attempts/refinement-02/artifact/scenes/"
    + "industrial_l04/variant-0/n/scene.json"
private let descriptorSHA256 =
    "bb4d38f44223083fe88b24f482b62a3061b0322e83e50836d8fb7b2d97b3c411"
private let materialPath =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
    + "art-proof/industrial-l04-crucible-gantry-v16-north-prepixel/materials/"
    + "industrial-l04-crucible-gantry-v14-north-prepixel.json"
private let materialSHA256 =
    "147c11d64be9fac934a6d4276a2e1a9d27f207bb1a1babd47222aaf5c2b3d202"
private let geometryID = "industrial-l04-crucible-gantry-v16-north-l-side-return"

private func argument(_ name: String, in arguments: [String]) throws -> String {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        throw IndustrialL4V16NorthSamplingResolverError.arguments
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
        throw IndustrialL4V16NorthSamplingResolverError.invalid(
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

private func assertContract(_ contract: EffectiveSamplingContract) throws {
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
        throw IndustrialL4V16NorthSamplingResolverError.invalid(
            "North did not resolve to the exact v3 contract"
        )
    }
}

private func mutatedDescriptor(
    source: Data,
    mutation: String
) throws -> SceneDescriptor {
    var root = try object(source)
    guard
        var sampling = root["sampling"] as? [String: Any],
        var material = root["materialLibrary"] as? [String: Any],
        var registration = root["registration"] as? [String: Any]
    else {
        throw IndustrialL4V16NorthSamplingResolverError.invalid(
            "v16 binding blocks missing"
        )
    }
    switch mutation {
    case "family":
        root["logicalBuildingID"] = "industrial_l03"
    case "variant":
        root["variantID"] = "variant-1"
    case "direction-north":
        root["viewDirection"] = "north"
    case "direction-east":
        root["viewDirection"] = "e"
    case "direction-south":
        root["viewDirection"] = "s"
    case "direction-west":
        root["viewDirection"] = "w"
    case "revision":
        root["sourceRevision"] = "source-v17-prepixel"
        sampling["sourceRevisionBinding"] = "source-v17-prepixel"
    case "binding":
        sampling["sourceRevisionBinding"] = "source-v07"
    case "geometry":
        root["sceneGeometryID"] =
            "industrial-l04-turbine-v16-n-wrong"
    case "authorship":
        root["authoredIndependently"] = false
    case "selection":
        root["productionSelected"] = true
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
    case "generic-fallback":
        sampling["sceneKitLightingMode"] = "lambert-scene-lights"
        sampling["sceneKitShadows"] = "current"
    case "material-path":
        material["file"] =
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "art-proof/industrial-l04-crucible-gantry-v16-north-prepixel/materials/"
            + "wrong.json"
    case "material-hash":
        material["sha256"] = String(repeating: "0", count: 64)
    case "transform-alias":
        registration["orientationTransform"] = "mirror-horizontal"
    default:
        throw IndustrialL4V16NorthSamplingResolverError.invalid(
            "unknown mutation \(mutation)"
        )
    }
    root["sampling"] = sampling
    root["materialLibrary"] = material
    root["registration"] = registration
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
        throw IndustrialL4V16NorthSamplingResolverError.invalid(
            "\(label) unexpectedly resolved"
        )
    } catch let error as SamplingContractError {
        return error.description
    }
}

private func write(_ object: Any, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw IndustrialL4V16NorthSamplingResolverError.invalid(
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
enum ValidateIndustrialL4V16NorthSamplingResolverMain {
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
        let sceneData = try Data(
            contentsOf: root.appendingPathComponent(descriptorPath)
        )
        let materialData = try Data(
            contentsOf: root.appendingPathComponent(materialPath)
        )
        guard sha256(sceneData) == descriptorSHA256 else {
            throw IndustrialL4V16NorthSamplingResolverError.invalid(
                "North descriptor hash drift"
            )
        }
        guard sha256(materialData) == materialSHA256 else {
            throw IndustrialL4V16NorthSamplingResolverError.invalid(
                "North material hash drift"
            )
        }
        let descriptor = try JSONDecoder().decode(
            SceneDescriptor.self,
            from: sceneData
        )
        guard
            descriptor.logicalBuildingID == "industrial_l04",
            descriptor.variantID == "variant-0",
            descriptor.viewDirection == "n",
            descriptor.sourceRevision == "source-v16-prepixel",
            descriptor.sceneGeometryID == geometryID,
            descriptor.authoredIndependently,
            !descriptor.productionSelected,
            descriptor.materialLibrary.file == materialPath,
            descriptor.materialLibrary.sha256 == materialSHA256,
            descriptor.sampling?.sourceRevisionBinding
                == "source-v16-prepixel",
            descriptor.registration.orientationTransform == "none"
        else {
            throw IndustrialL4V16NorthSamplingResolverError.invalid(
                "North identity binding drift"
            )
        }
        let contract = try DescriptorSamplingResolver.resolve(
            descriptor: descriptor
        )
        try assertContract(contract)

        let mutations = [
            "family",
            "variant",
            "direction-north",
            "direction-east",
            "direction-south",
            "direction-west",
            "revision",
            "binding",
            "geometry",
            "authorship",
            "selection",
            "purpose",
            "contract",
            "lighting",
            "shadows",
            "antialiasing",
            "generic-fallback",
            "material-path",
            "material-hash",
            "transform-alias",
        ]
        let negatives = try mutations.map { mutation in
            [
                "mutation": mutation,
                "failedClosed": true,
                "resolverError": try failure(
                    mutatedDescriptor(
                        source: sceneData,
                        mutation: mutation
                    ),
                    label: mutation
                ),
            ]
        }
        let record = effectiveRecord(contract)
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "scope":
                "hash-and-material-bound Industrial L4 source-v16-prepixel "
                + "North-only resolver",
            "descriptorFile": descriptorPath,
            "descriptorSHA256": descriptorSHA256,
            "sceneGeometryID": geometryID,
            "materialFile": materialPath,
            "materialSHA256": materialSHA256,
            "effectiveContractRecord": record,
            "effectiveContractRecordSHA256":
                sha256(try jsonData(record)),
            "positiveCount": 1,
            "negativeCount": negatives.count,
            "negativeCases": negatives,
            "eastSouthWestRejected": true,
            "longFormNorthRejected": true,
            "genericFallbackRejected": true,
            "descriptorMutationCount": 0,
            "materialMutationCount": 0,
            "rawRenderProcesses": 0,
            "sceneKitProcesses": 0,
            "metalProcesses": 0,
            "normalizerProcesses": 0,
            "sourceAuthority": false,
            "familyAuthority": false,
            "productionSelected": false,
            "passed": negatives.count == mutations.count,
        ]
        try write(report, to: reportURL)
    }
}
