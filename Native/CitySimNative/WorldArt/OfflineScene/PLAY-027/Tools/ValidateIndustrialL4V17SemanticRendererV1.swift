import CryptoKit
import Foundation

private enum SemanticContractValidationError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: validate-industrial-l4-v17-semantic-renderer-v1 --repository-root <path> --report <json>"
        case let .invalid(message):
            return message
        }
    }
}

private let descriptorPath =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/"
    + "industrial-l04-crucible-gantry-v17-north-prepixel/artifact/scenes/"
    + "industrial_l04/variant-0/n/scene.json"
private let materialPath =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/"
    + "industrial-l04-crucible-gantry-v17-north-prepixel/materials/"
    + "industrial-l04-crucible-gantry-v14-north-prepixel.json"
private let contractSourcePath =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/"
    + "SemanticVisibilityRendererV1.swift"
private let rendererSourcePath =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/"
    + "OfflineSceneRenderer.swift"
private let validatorSourcePath =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/"
    + "ValidateIndustrialL4V17SemanticRendererV1.swift"

private func argument(_ name: String) throws -> String {
    guard
        let index = CommandLine.arguments.firstIndex(of: name),
        index + 1 < CommandLine.arguments.count
    else {
        throw SemanticContractValidationError.arguments
    }
    return CommandLine.arguments[index + 1]
}

private func digest(_ data: Data) -> String {
    SHA256.hash(data: data)
        .map { String(format: "%02x", $0) }
        .joined()
}

private func digest(_ url: URL) throws -> String {
    digest(try Data(contentsOf: url))
}

private func mutatedDescriptor(
    data: Data,
    key: String,
    value: Any
) throws -> SceneDescriptor {
    guard
        var object = try JSONSerialization.jsonObject(with: data)
            as? [String: Any]
    else {
        throw SemanticContractValidationError.invalid(
            "descriptor JSON malformed"
        )
    }
    object[key] = value
    return try JSONDecoder().decode(
        SceneDescriptor.self,
        from: JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
    )
}

private func sampling(
    from source: EffectiveSamplingContract,
    antialiasing: String? = nil,
    shadows: String? = nil,
    lighting: String? = nil,
    purpose: String? = nil
) -> EffectiveSamplingContract {
    EffectiveSamplingContract(
        contractID: source.contractID,
        descriptorSchema: source.descriptorSchema,
        sceneKitAntialiasing:
            antialiasing ?? source.sceneKitAntialiasing,
        sceneKitShadows: shadows ?? source.sceneKitShadows,
        sceneKitLightingMode: lighting ?? source.sceneKitLightingMode,
        linearOversamplingFactor: source.linearOversamplingFactor,
        downsampleFilter: source.downsampleFilter,
        downsampleScale: source.downsampleScale,
        downsampleAspectRatio: source.downsampleAspectRatio,
        ciUseSoftwareRenderer: source.ciUseSoftwareRenderer,
        ciCacheIntermediates: source.ciCacheIntermediates,
        ciWorkingColorSpace: source.ciWorkingColorSpace,
        ciOutputColorSpace: source.ciOutputColorSpace,
        quantizerID: source.quantizerID,
        quantizerStep: source.quantizerStep,
        quantizerMidpointOffset: source.quantizerMidpointOffset,
        chromaBypassRGBA: source.chromaBypassRGBA,
        canonicalizerID: source.canonicalizerID,
        canonicalizerEncoder: source.canonicalizerEncoder,
        canonicalizerPostEncoder: source.canonicalizerPostEncoder,
        canonicalizerFormat: source.canonicalizerFormat,
        preLanczosCanonicalizer: source.preLanczosCanonicalizer,
        postQuantizationCanonicalizer:
            source.postQuantizationCanonicalizer,
        purpose: purpose ?? source.purpose
    )
}

private struct ValidationContext {
    let root: URL
    let sceneURL: URL
    let materialURL: URL
    let descriptor: SceneDescriptor
    let sampling: EffectiveSamplingContract
}

private func invoke(
    _ context: ValidationContext,
    contractID: String? =
        PLAY027SemanticRendererV1.contractID,
    sceneSHA: String =
        PLAY027SemanticRendererV1.descriptorSHA256,
    materialSHA: String =
        PLAY027SemanticRendererV1.materialSHA256,
    descriptor: SceneDescriptor? = nil,
    sampling: EffectiveSamplingContract? = nil,
    run: String = "run-a",
    competingDiagnosticContract: String? = nil
) throws -> PLAY027SemanticRendererV1Record? {
    let directory = context.root.appendingPathComponent(
        PLAY027SemanticRendererV1.evidenceRoot + "/\(run)"
    )
    return try PLAY027SemanticRendererV1.validate(
        requestedContractID: contractID,
        repositoryRoot: context.root,
        sceneURL: context.sceneURL,
        sceneSHA256: sceneSHA,
        materialsURL: context.materialURL,
        materialSHA256: materialSHA,
        outputURL: directory.appendingPathComponent("semantic.png"),
        recordURL: directory.appendingPathComponent("provenance.json"),
        descriptor: descriptor ?? context.descriptor,
        sampling: sampling ?? context.sampling,
        diagnosticSamplingPipelineID: nil,
        diagnosticContractID: competingDiagnosticContract,
        diagnosticStageContractID: nil,
        diagnosticL3V5TraceContractID: nil,
        diagnosticStageCaptureDirectory: nil,
        diagnosticStageCoordinate: nil,
        diagnosticPrequantizedOutput: nil,
        diagnosticAntialiasing: nil,
        diagnosticSceneShadows: nil,
        diagnosticMaterialLighting: nil
    )
}

private func rejected(
    _ name: String,
    _ body: () throws -> Void
) throws -> [String: Any] {
    do {
        try body()
        throw SemanticContractValidationError.invalid(
            "negative admitted: \(name)"
        )
    } catch let error as PLAY027SemanticRendererV1Error {
        return [
            "name": name,
            "rejected": true,
            "reason": error.description,
        ]
    }
}

@main
private enum ValidateIndustrialL4V17SemanticRendererV1 {
    static func main() throws {
        let root = URL(
            fileURLWithPath: try argument("--repository-root")
        ).standardizedFileURL
        let reportURL = URL(
            fileURLWithPath: try argument("--report")
        ).standardizedFileURL
        guard !FileManager.default.fileExists(atPath: reportURL.path) else {
            throw SemanticContractValidationError.invalid(
                "report path must be absent"
            )
        }
        let sceneURL = root.appendingPathComponent(descriptorPath)
        let materialURL = root.appendingPathComponent(materialPath)
        let descriptorData = try Data(contentsOf: sceneURL)
        let descriptor = try JSONDecoder().decode(
            SceneDescriptor.self,
            from: descriptorData
        )
        let resolved = try DescriptorSamplingResolver.resolve(
            descriptor: descriptor
        )
        let context = ValidationContext(
            root: root,
            sceneURL: sceneURL,
            materialURL: materialURL,
            descriptor: descriptor,
            sampling: resolved
        )
        guard
            let positive = try invoke(context),
            positive.value["contractID"] as? String
                == PLAY027SemanticRendererV1.contractID,
            try invoke(context, run: "run-b") != nil
        else {
            throw SemanticContractValidationError.invalid(
                "positive semantic contract missing"
            )
        }

        let negatives = try [
            rejected("contractID") {
                _ = try invoke(context, contractID: "wrong")
            },
            rejected("descriptorSHA256") {
                _ = try invoke(
                    context,
                    sceneSHA: String(repeating: "0", count: 64)
                )
            },
            rejected("materialSHA256") {
                _ = try invoke(
                    context,
                    materialSHA: String(repeating: "1", count: 64)
                )
            },
            rejected("sourceRevision") {
                _ = try invoke(
                    context,
                    descriptor: try mutatedDescriptor(
                        data: descriptorData,
                        key: "sourceRevision",
                        value: "source-v18-prepixel"
                    )
                )
            },
            rejected("direction") {
                _ = try invoke(
                    context,
                    descriptor: try mutatedDescriptor(
                        data: descriptorData,
                        key: "viewDirection",
                        value: "e"
                    )
                )
            },
            rejected("geometry") {
                _ = try invoke(
                    context,
                    descriptor: try mutatedDescriptor(
                        data: descriptorData,
                        key: "sceneGeometryID",
                        value: "mutated"
                    )
                )
            },
            rejected("antialiasing") {
                _ = try invoke(
                    context,
                    sampling: sampling(
                        from: resolved,
                        antialiasing: "multisampling4X"
                    )
                )
            },
            rejected("shadows") {
                _ = try invoke(
                    context,
                    sampling: sampling(from: resolved, shadows: "current")
                )
            },
            rejected("lighting") {
                _ = try invoke(
                    context,
                    sampling: sampling(
                        from: resolved,
                        lighting: "lambert-scene-lights"
                    )
                )
            },
            rejected("purpose") {
                _ = try invoke(
                    context,
                    sampling: sampling(
                        from: resolved,
                        purpose: "diagnostic-regression"
                    )
                )
            },
            rejected("outputRun") {
                _ = try invoke(context, run: "run-c")
            },
            rejected("competingDiagnostic") {
                _ = try invoke(
                    context,
                    competingDiagnosticContract: "competing"
                )
            },
        ]

        let report: [String: Any] = [
            "taskID": "PLAY-027",
            "contract": "CONTRACT-019",
            "artifact": "industrial-l04-v17-semantic-renderer-v1-contract",
            "disposition": "PASS_PREPIXEL_SEMANTIC_RENDERER_CONTRACT",
            "sourceAuthority": false,
            "productionSelected": false,
            "processCounts": [
                "metal": 0,
                "sceneKitRenderer": 0,
                "raw": 0,
                "normalizer": 0,
            ],
            "binding": [
                "descriptor": descriptorPath,
                "descriptorSHA256": try digest(sceneURL),
                "materialLibrary": materialPath,
                "materialLibrarySHA256": try digest(materialURL),
                "sceneGeometryID": descriptor.sceneGeometryID,
                "semanticContractID":
                    PLAY027SemanticRendererV1.contractID,
            ],
            "positive": positive.value,
            "negativeCases": negatives,
            "tool": [
                "contractSource": contractSourcePath,
                "contractSourceSHA256": try digest(
                    root.appendingPathComponent(contractSourcePath)
                ),
                "rendererSource": rendererSourcePath,
                "rendererSourceSHA256": try digest(
                    root.appendingPathComponent(rendererSourcePath)
                ),
                "validatorSource": validatorSourcePath,
                "validatorSourceSHA256": try digest(
                    root.appendingPathComponent(validatorSourcePath)
                ),
                "binarySHA256": try digest(
                    URL(fileURLWithPath: CommandLine.arguments[0])
                ),
            ],
        ]
        var data = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys]
        )
        data.append(0x0A)
        try FileManager.default.createDirectory(
            at: reportURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: reportURL, options: .atomic)
        print("PASS semantic-visibility-renderer-v1 contract")
        print("negative-count=\(negatives.count)")
    }
}
