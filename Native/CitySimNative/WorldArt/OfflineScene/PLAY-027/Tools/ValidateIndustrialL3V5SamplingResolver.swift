import CryptoKit
import Foundation

enum IndustrialL3V5SamplingResolverError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return """
            usage: validate-industrial-l3-v5-sampling-resolver \
              --repository-root <path> \
              --mode legacy-baseline|full \
              --report <json> \
              [--baseline-report <json>]
            """
        case let .invalid(message):
            return message
        }
    }
}

private struct FrozenDescriptor {
    let revision: String
    let direction: String
    let relativePath: String
    let sha256: String
    let geometryID: String?

    var key: String {
        "\(revision)/\(direction)"
    }
}

private let rendererArchitectureRelative =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
    + "Sources/RendererArchitecture.swift"

private let frozenV5Descriptors = [
    FrozenDescriptor(
        revision: "source-v05",
        direction: "north",
        relativePath:
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "art-proof/industrial-l03-cohesion-frontage-v01/scenes/"
            + "industrial_l03/variant-0/north/scene.json",
        sha256:
            "a147ad0a7023374b982a6677325da2912f45796616b03579e1a72eb7da4a6b61",
        geometryID: "industrial-l03-north-v05-open-loading-court"
    ),
    FrozenDescriptor(
        revision: "source-v05",
        direction: "west",
        relativePath:
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "art-proof/industrial-l03-cohesion-frontage-v01/scenes/"
            + "industrial_l03/variant-0/west/scene.json",
        sha256:
            "56e9aef896ef5eef435f76ff466f837ac022ff18edbc4e6bd3fa24cb583d78dc",
        geometryID: "industrial-l03-west-v05-open-loading-court"
    ),
]

private let frozenLegacyDescriptors = [
    FrozenDescriptor(
        revision: "source-v02",
        direction: "north",
        relativePath:
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "art-proof/industrial-l03-directional-family-v02/scenes/"
            + "industrial_l03/variant-0/north/scene.json",
        sha256:
            "78803712a2b4118abef6ff90119444b1c4093f5cb442348f3cdb9b3e4bf1fe51",
        geometryID: nil
    ),
    FrozenDescriptor(
        revision: "source-v02",
        direction: "east",
        relativePath:
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "art-proof/industrial-l03-directional-family-v02/scenes/"
            + "industrial_l03/variant-0/east/scene.json",
        sha256:
            "dbe0dd260d28d848864d4194826f5147ec91314cf75b95bff9349bbfe466342c",
        geometryID: nil
    ),
    FrozenDescriptor(
        revision: "source-v02",
        direction: "south",
        relativePath:
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "art-proof/industrial-l03-directional-family-v02/scenes/"
            + "industrial_l03/variant-0/south/scene.json",
        sha256:
            "1e548d4694bea47b36e9aca1a97e901917ea92742fd6366f53a4e92bfcba1b2b",
        geometryID: nil
    ),
    FrozenDescriptor(
        revision: "source-v02",
        direction: "west",
        relativePath:
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "art-proof/industrial-l03-directional-family-v02/scenes/"
            + "industrial_l03/variant-0/west/scene.json",
        sha256:
            "bc0812eb16008bb0a544873fb3d24c4b01c470c405b4f6051a36a400c68856ce",
        geometryID: nil
    ),
    FrozenDescriptor(
        revision: "source-v03",
        direction: "north",
        relativePath:
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "art-proof/industrial-l03-directional-family-v03/scenes/"
            + "industrial_l03/variant-0/north/scene.json",
        sha256:
            "11b559a3b2ba4c679a22cd063f94cec56c06c4f46c9c93af2832d31eb06b6bf9",
        geometryID: nil
    ),
    FrozenDescriptor(
        revision: "source-v03",
        direction: "east",
        relativePath:
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "art-proof/industrial-l03-directional-family-v03/scenes/"
            + "industrial_l03/variant-0/east/scene.json",
        sha256:
            "1a4687b3ac6db8492ee8030f44dc04d99db163d460c5b923fb628a72d8279448",
        geometryID: nil
    ),
    FrozenDescriptor(
        revision: "source-v03",
        direction: "south",
        relativePath:
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "art-proof/industrial-l03-directional-family-v03/scenes/"
            + "industrial_l03/variant-0/south/scene.json",
        sha256:
            "e0d286c55bfd79527faf87b3c5c75b725ec5dea4394b2d3e1af13b57642f9126",
        geometryID: nil
    ),
    FrozenDescriptor(
        revision: "source-v03",
        direction: "west",
        relativePath:
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "art-proof/industrial-l03-directional-family-v03/scenes/"
            + "industrial_l03/variant-0/west/scene.json",
        sha256:
            "46cfb19f041bb3303cf4fd5d84a84e111c5892122512859202bfe2b59410bfaf",
        geometryID: nil
    ),
    FrozenDescriptor(
        revision: "source-v04",
        direction: "north",
        relativePath:
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "art-proof/industrial-l03-cohesion-siblings-v01/scenes/"
            + "industrial_l03/variant-0/north/scene.json",
        sha256:
            "1afaefb06e8e6a91f3e3e6215e9721f1ce8de224cc790e1599c33f956afa12be",
        geometryID: nil
    ),
    FrozenDescriptor(
        revision: "source-v04",
        direction: "east",
        relativePath:
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "art-proof/industrial-l03-cohesion-east-v01/scenes/"
            + "industrial_l03/variant-0/east/scene.json",
        sha256:
            "1e5c69a03a6298f64f4d4d13bb0f523690729b82d5565343f40aaa8278aa3b6d",
        geometryID: nil
    ),
    FrozenDescriptor(
        revision: "source-v04",
        direction: "south",
        relativePath:
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "art-proof/industrial-l03-cohesion-siblings-v01/scenes/"
            + "industrial_l03/variant-0/south/scene.json",
        sha256:
            "31c7eef5e3f461b97b116288274baa8bc5980ef711d45401645e2925ac326a48",
        geometryID: nil
    ),
    FrozenDescriptor(
        revision: "source-v04",
        direction: "west",
        relativePath:
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/"
            + "art-proof/industrial-l03-cohesion-siblings-v01/scenes/"
            + "industrial_l03/variant-0/west/scene.json",
        sha256:
            "9107f7b1055b9b4e523071614687ccf6a9fef728a7318339b1951dfe1a775e1c",
        geometryID: nil
    ),
]

private func argument(
    _ name: String,
    in arguments: [String],
    required: Bool = true
) throws -> String? {
    guard
        let index = arguments.firstIndex(of: name),
        index + 1 < arguments.count
    else {
        if required {
            throw IndustrialL3V5SamplingResolverError.arguments
        }
        return nil
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
        throw IndustrialL3V5SamplingResolverError.invalid(
            "JSON object expected"
        )
    }
    return object
}

private func encodedObject<T: Encodable>(_ value: T?) throws -> Any {
    guard let value else {
        return NSNull()
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try JSONSerialization.jsonObject(
        with: encoder.encode(value)
    )
}

private func effectiveRecord(
    _ contract: EffectiveSamplingContract
) throws -> [String: Any] {
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
        "preLanczosCanonicalizer":
            try encodedObject(contract.preLanczosCanonicalizer),
        "postQuantizationCanonicalizer":
            try encodedObject(contract.postQuantizationCanonicalizer),
        "purpose": contract.purpose,
    ]
}

private func descriptor(
    _ frozen: FrozenDescriptor,
    root: URL
) throws -> (SceneDescriptor, Data) {
    let data = try Data(
        contentsOf: root.appendingPathComponent(frozen.relativePath)
    )
    guard sha256(data) == frozen.sha256 else {
        throw IndustrialL3V5SamplingResolverError.invalid(
            "\(frozen.key) descriptor hash drift"
        )
    }
    let decoded = try JSONDecoder().decode(
        SceneDescriptor.self,
        from: data
    )
    return (decoded, data)
}

private func legacyCases(root: URL) throws -> [[String: Any]] {
    try frozenLegacyDescriptors.map { frozen in
        let loaded = try descriptor(frozen, root: root)
        let contract = try DescriptorSamplingResolver.resolve(
            descriptor: loaded.0
        )
        let record = try effectiveRecord(contract)
        return [
            "key": frozen.key,
            "revision": frozen.revision,
            "direction": frozen.direction,
            "descriptorFile": frozen.relativePath,
            "descriptorSHA256": frozen.sha256,
            "effectiveContractRecord": record,
            "effectiveContractRecordSHA256":
                sha256(try jsonData(record)),
        ]
    }
}

private func assertV5Contract(
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
        throw IndustrialL3V5SamplingResolverError.invalid(
            "\(direction) did not resolve to the exact frozen v3 contract"
        )
    }
}

private func mutatedDescriptor(
    from sourceData: Data,
    mutation: String
) throws -> SceneDescriptor {
    var object = try jsonObject(sourceData)
    guard var sampling = object["sampling"] as? [String: Any] else {
        throw IndustrialL3V5SamplingResolverError.invalid(
            "source-v05 sampling block missing"
        )
    }
    switch mutation {
    case "direction":
        object["viewDirection"] = "northeast"
    case "source-v05-east":
        object["viewDirection"] = "east"
        object["sceneGeometryID"] =
            "industrial-l03-east-v05-open-loading-court"
    case "source-v05-south":
        object["viewDirection"] = "south"
        object["sceneGeometryID"] =
            "industrial-l03-south-v05-open-loading-court"
    case "variant":
        object["variantID"] = "variant-1"
    case "revision":
        object["sourceRevision"] = "source-v06"
        sampling["sourceRevisionBinding"] = "source-v06"
    case "binding":
        sampling["sourceRevisionBinding"] = "source-v04"
    case "geometry":
        object["sceneGeometryID"] =
            "industrial-l03-north-v05-wrong-geometry"
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
    default:
        throw IndustrialL3V5SamplingResolverError.invalid(
            "unknown mutation \(mutation)"
        )
    }
    object["sampling"] = sampling
    return try JSONDecoder().decode(
        SceneDescriptor.self,
        from: try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
    )
}

private func failure(
    _ descriptor: SceneDescriptor,
    label: String
) throws -> String {
    do {
        _ = try DescriptorSamplingResolver.resolve(
            descriptor: descriptor
        )
        throw IndustrialL3V5SamplingResolverError.invalid(
            "\(label) unexpectedly resolved"
        )
    } catch let error as SamplingContractError {
        return error.description
    }
}

private func write(_ object: Any, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw IndustrialL3V5SamplingResolverError.invalid(
            "report output must be absent"
        )
    }
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try jsonData(object).write(to: url, options: .atomic)
}

private func repositoryRelativePath(_ url: URL, root: URL) -> String {
    let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
    guard url.path.hasPrefix(prefix) else {
        return url.path
    }
    return String(url.path.dropFirst(prefix.count))
}

@main
enum ValidateIndustrialL3V5SamplingResolverMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard
            let rootPath = try argument(
                "--repository-root",
                in: arguments
            ),
            let mode = try argument("--mode", in: arguments),
            let reportPath = try argument("--report", in: arguments),
            ["legacy-baseline", "full"].contains(mode)
        else {
            throw IndustrialL3V5SamplingResolverError.arguments
        }
        let root = URL(fileURLWithPath: rootPath).standardizedFileURL
        let reportURL = URL(
            fileURLWithPath: reportPath
        ).standardizedFileURL
        let rendererData = try Data(
            contentsOf: root.appendingPathComponent(
                rendererArchitectureRelative
            )
        )
        let currentLegacyCases = try legacyCases(root: root)

        if mode == "legacy-baseline" {
            try write([
                "schema": 1,
                "task": "PLAY-027",
                "mode": mode,
                "rendererArchitectureFile":
                    rendererArchitectureRelative,
                "rendererArchitectureSHA256":
                    sha256(rendererData),
                "legacyCaseCount": currentLegacyCases.count,
                "legacyCases": currentLegacyCases,
                "rawRenderProcesses": 0,
                "sceneKitProcesses": 0,
                "metalProcesses": 0,
                "normalizerProcesses": 0,
                "passed": currentLegacyCases.count == 12,
            ], to: reportURL)
            return
        }

        guard
            let baselinePath = try argument(
                "--baseline-report",
                in: arguments
            )
        else {
            throw IndustrialL3V5SamplingResolverError.arguments
        }
        let baselineURL = URL(
            fileURLWithPath: baselinePath
        ).standardizedFileURL
        let baselineObject = try jsonObject(
            Data(contentsOf: baselineURL)
        )
        guard
            let baselineCases =
                baselineObject["legacyCases"] as? [[String: Any]],
            sha256(try jsonData(baselineCases))
                == sha256(try jsonData(currentLegacyCases))
        else {
            throw IndustrialL3V5SamplingResolverError.invalid(
                "legacy effective-contract records drifted"
            )
        }

        var positiveCases: [[String: Any]] = []
        var mutationSourceData: Data?
        for frozen in frozenV5Descriptors {
            let loaded = try descriptor(frozen, root: root)
            guard
                loaded.0.logicalBuildingID == "industrial_l03",
                loaded.0.variantID == "variant-0",
                loaded.0.sourceRevision == "source-v05",
                loaded.0.viewDirection == frozen.direction,
                loaded.0.sceneGeometryID == frozen.geometryID,
                loaded.0.sampling?.sourceRevisionBinding == "source-v05",
                loaded.0.sampling?.purpose == "source-authority",
                loaded.0.sampling?.contractID
                    == DescriptorSamplingResolver.schema2ContractV3ID,
                loaded.0.sampling?.sceneKitAntialiasing == "none",
                loaded.0.sampling?.sceneKitShadows == "disabled",
                loaded.0.sampling?.sceneKitLightingMode
                    == "authored-constant-v1"
            else {
                throw IndustrialL3V5SamplingResolverError.invalid(
                    "\(frozen.direction) bound identity drift"
                )
            }
            let contract = try DescriptorSamplingResolver.resolve(
                descriptor: loaded.0
            )
            try assertV5Contract(contract, direction: frozen.direction)
            let record = try effectiveRecord(contract)
            positiveCases.append([
                "direction": frozen.direction,
                "descriptorFile": frozen.relativePath,
                "descriptorSHA256": frozen.sha256,
                "sceneGeometryID": frozen.geometryID as Any,
                "effectiveContractRecord": record,
                "effectiveContractRecordSHA256":
                    sha256(try jsonData(record)),
                "passed": true,
            ])
            if mutationSourceData == nil {
                mutationSourceData = loaded.1
            }
        }
        guard let mutationSourceData else {
            throw IndustrialL3V5SamplingResolverError.invalid(
                "source-v05 mutation source missing"
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
            "source-v05-east",
            "source-v05-south",
        ]
        let negativeCases = try mutations.map { mutation in
            [
                "mutation": mutation,
                "failedClosed": true,
                "resolverError": try failure(
                    mutatedDescriptor(
                        from: mutationSourceData,
                        mutation: mutation
                    ),
                    label: mutation
                ),
            ]
        }
        let baselineRendererHash =
            baselineObject["rendererArchitectureSHA256"] as? String
            ?? "missing"
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "mode": mode,
            "scope":
                "hash-bound Industrial L3 source-v05 North/West "
                + "schema-2 v3 resolver capability",
            "rendererArchitectureFile": rendererArchitectureRelative,
            "rendererArchitectureBeforeSHA256": baselineRendererHash,
            "rendererArchitectureAfterSHA256": sha256(rendererData),
            "positiveCount": positiveCases.count,
            "positiveCases": positiveCases,
            "negativeCount": negativeCases.count,
            "negativeCases": negativeCases,
            "sourceV05EastRejected": true,
            "sourceV05SouthRejected": true,
            "legacyDescriptorCount": currentLegacyCases.count,
            "legacyDescriptorFileIdentityPreserved": true,
            "legacyEffectiveContractRecordsByteIdentical": true,
            "legacyBaselineReport":
                repositoryRelativePath(baselineURL, root: root),
            "descriptorMutationCount": 0,
            "rawRenderProcesses": 0,
            "sceneKitProcesses": 0,
            "metalProcesses": 0,
            "normalizerProcesses": 0,
            "productionSelected": false,
            "passed":
                positiveCases.count == 2
                && negativeCases.count == mutations.count
                && currentLegacyCases.count == 12,
        ]
        try write(report, to: reportURL)
    }
}
