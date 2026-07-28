import AppKit
import CryptoKit
import Foundation
import SceneKit

private enum ValidationError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: validate-industrial-l4-v18-foundation-repair --repository-root <path> --report <json>"
        case let .invalid(message):
            return message
        }
    }
}

private let descriptorPath =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/"
    + "industrial-l04-crucible-gantry-v18-north-prepixel/artifact/scenes/"
    + "industrial_l04/variant-0/n/scene.json"
private let v17DescriptorPath =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/"
    + "industrial-l04-crucible-gantry-v17-north-prepixel/artifact/scenes/"
    + "industrial_l04/variant-0/n/scene.json"
private let materialPath =
    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/art-proof/"
    + "industrial-l04-crucible-gantry-v17-north-prepixel/materials/"
    + "industrial-l04-crucible-gantry-v14-north-prepixel.json"
private let expectedDescriptorSHA =
    "3696b813e6c3e0f46251e689582163bdbdcc5d84a3a9c1125bfbefba37da2630"
private let expectedV17DescriptorSHA =
    "6cb190ea388746c620945ff401a03817df0ff1f92797a18fff8e86b00b0cd94a"
private let expectedMaterialSHA =
    "147c11d64be9fac934a6d4276a2e1a9d27f207bb1a1babd47222aaf5c2b3d202"

private func argument(_ name: String) throws -> String {
    guard
        let index = CommandLine.arguments.firstIndex(of: name),
        index + 1 < CommandLine.arguments.count
    else {
        throw ValidationError.arguments
    }
    return CommandLine.arguments[index + 1]
}

private func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func digest(_ url: URL) throws -> String {
    digest(try Data(contentsOf: url))
}

private func descriptor(
    from data: Data,
    mutate: (inout [String: Any]) throws -> Void
) throws -> SceneDescriptor {
    guard
        var object = try JSONSerialization.jsonObject(with: data)
            as? [String: Any]
    else {
        throw ValidationError.invalid("descriptor JSON malformed")
    }
    try mutate(&object)
    return try JSONDecoder().decode(
        SceneDescriptor.self,
        from: JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
    )
}

private func sampling(
    _ source: EffectiveSamplingContract,
    antialiasing: String? = nil,
    shadows: String? = nil,
    lighting: String? = nil,
    purpose: String? = nil
) -> EffectiveSamplingContract {
    EffectiveSamplingContract(
        contractID: source.contractID,
        descriptorSchema: source.descriptorSchema,
        sceneKitAntialiasing: antialiasing ?? source.sceneKitAntialiasing,
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
        postQuantizationCanonicalizer: source.postQuantizationCanonicalizer,
        purpose: purpose ?? source.purpose
    )
}

private struct Context {
    let root: URL
    let descriptorURL: URL
    let materialURL: URL
    let descriptor: SceneDescriptor
    let sampling: EffectiveSamplingContract
}

private func invoke(
    _ context: Context,
    contractID: String? = PLAY027SemanticRendererV1.r3ContractID,
    sceneSHA: String = PLAY027SemanticRendererV1.r3DescriptorSHA256,
    materialSHA: String = PLAY027SemanticRendererV1.materialSHA256,
    descriptor: SceneDescriptor? = nil,
    sampling: EffectiveSamplingContract? = nil,
    run: String = "run-a",
    competing: String? = nil
) throws -> PLAY027SemanticRendererV1Record? {
    let directory = context.root.appendingPathComponent(
        PLAY027SemanticRendererV1.r3EvidenceRoot + "/\(run)"
    )
    return try PLAY027SemanticRendererV1.validate(
        requestedContractID: contractID,
        repositoryRoot: context.root,
        sceneURL: context.descriptorURL,
        sceneSHA256: sceneSHA,
        materialsURL: context.materialURL,
        materialSHA256: materialSHA,
        outputURL: directory.appendingPathComponent("semantic.png"),
        recordURL: directory.appendingPathComponent("provenance.json"),
        descriptor: descriptor ?? context.descriptor,
        sampling: sampling ?? context.sampling,
        diagnosticSamplingPipelineID: nil,
        diagnosticContractID: competing,
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
        throw ValidationError.invalid("negative admitted: \(name)")
    } catch let error as PLAY027SemanticRendererV1Error {
        return [
            "name": name,
            "rejected": true,
            "reason": error.description,
        ]
    }
}

private func resolverRejected(
    _ name: String,
    descriptor: SceneDescriptor
) throws -> [String: Any] {
    do {
        _ = try DescriptorSamplingResolver.resolve(descriptor: descriptor)
        throw ValidationError.invalid("resolver negative admitted: \(name)")
    } catch {
        return [
            "name": name,
            "rejected": true,
            "reason": String(describing: error),
        ]
    }
}

@main
private enum ValidateRepair {
    static func main() throws {
        let root = URL(
            fileURLWithPath: try argument("--repository-root")
        ).standardizedFileURL
        let reportURL = URL(
            fileURLWithPath: try argument("--report")
        ).standardizedFileURL
        guard !FileManager.default.fileExists(atPath: reportURL.path) else {
            throw ValidationError.invalid("report path must be absent")
        }
        let descriptorURL = root.appendingPathComponent(descriptorPath)
        let v17URL = root.appendingPathComponent(v17DescriptorPath)
        let materialURL = root.appendingPathComponent(materialPath)
        let descriptorData = try Data(contentsOf: descriptorURL)
        let v17Data = try Data(contentsOf: v17URL)
        guard
            digest(descriptorData) == expectedDescriptorSHA,
            digest(v17Data) == expectedV17DescriptorSHA,
            try digest(materialURL) == expectedMaterialSHA
        else {
            throw ValidationError.invalid("frozen input hash drift")
        }
        let decoder = JSONDecoder()
        let candidate = try decoder.decode(
            SceneDescriptor.self,
            from: descriptorData
        )
        let v17 = try decoder.decode(SceneDescriptor.self, from: v17Data)
        let materialDescriptor = try decoder.decode(
            MaterialLibraryDescriptor.self,
            from: Data(contentsOf: materialURL)
        )
        let resolved = try DescriptorSamplingResolver.resolve(
            descriptor: candidate
        )
        let v17Resolved = try DescriptorSamplingResolver.resolve(descriptor: v17)
        guard
            resolved.contractID == v17Resolved.contractID,
            resolved.linearOversamplingFactor
                == v17Resolved.linearOversamplingFactor,
            resolved.sceneKitAntialiasing
                == v17Resolved.sceneKitAntialiasing,
            resolved.sceneKitShadows == v17Resolved.sceneKitShadows,
            resolved.sceneKitLightingMode
                == v17Resolved.sceneKitLightingMode,
            resolved.downsampleFilter == v17Resolved.downsampleFilter,
            resolved.downsampleScale == v17Resolved.downsampleScale,
            resolved.quantizerID == v17Resolved.quantizerID,
            resolved.canonicalizerID == v17Resolved.canonicalizerID,
            resolved.purpose == v17Resolved.purpose
        else {
            throw ValidationError.invalid("v17 effective sampling drift")
        }
        let builder = ContractSceneBuilder(
            materials: NativeMaterialLibrary(
                descriptor: materialDescriptor,
                repositoryRoot: root
            )
        )
        let scene = try builder.buildScene(from: candidate)
        var nodeNames: [String] = []
        scene.rootNode.enumerateChildNodes { node, _ in
            if node.geometry != nil, let name = node.name {
                nodeNames.append(name)
            }
        }
        nodeNames.sort()
        guard
            nodeNames.count == 51,
            nodeNames.contains("foundation"),
            !nodeNames.contains("v16-foundation")
        else {
            throw ValidationError.invalid(
                "expected 51 geometry nodes with one canonical foundation; "
                    + "actual=\(nodeNames.count), canonical="
                    + "\(nodeNames.filter { $0 == "foundation" }.count), "
                    + "redundant="
                    + "\(nodeNames.filter { $0 == "v16-foundation" }.count)"
            )
        }
        let semantic = try PLAY027SemanticRendererV1.apply(to: scene)
        guard semantic.nodeRecords.count == 51 else {
            throw ValidationError.invalid("semantic manifest is not 51 nodes")
        }
        let context = Context(
            root: root,
            descriptorURL: descriptorURL,
            materialURL: materialURL,
            descriptor: candidate,
            sampling: resolved
        )
        guard
            let positiveA = try invoke(context),
            try invoke(context, run: "run-b") != nil
        else {
            throw ValidationError.invalid("positive contract missing")
        }

        var negatives = try [
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
                    descriptor: try descriptor(from: descriptorData) {
                        $0["sourceRevision"] = "source-v17-prepixel"
                    }
                )
            },
            rejected("direction") {
                _ = try invoke(
                    context,
                    descriptor: try descriptor(from: descriptorData) {
                        $0["viewDirection"] = "e"
                    }
                )
            },
            rejected("geometry") {
                _ = try invoke(
                    context,
                    descriptor: try descriptor(from: descriptorData) {
                        $0["sceneGeometryID"] = "mutated"
                    }
                )
            },
            rejected("antialiasing") {
                _ = try invoke(
                    context,
                    sampling: sampling(
                        resolved,
                        antialiasing: "multisampling4X"
                    )
                )
            },
            rejected("shadows") {
                _ = try invoke(
                    context,
                    sampling: sampling(resolved, shadows: "current")
                )
            },
            rejected("lighting") {
                _ = try invoke(
                    context,
                    sampling: sampling(
                        resolved,
                        lighting: "lambert-scene-lights"
                    )
                )
            },
            rejected("purpose") {
                _ = try invoke(
                    context,
                    sampling: sampling(
                        resolved,
                        purpose: "diagnostic-regression"
                    )
                )
            },
            rejected("outputRun") {
                _ = try invoke(context, run: "run-c")
            },
            rejected("competingDiagnostic") {
                _ = try invoke(context, competing: "competing")
            },
        ]
        negatives.append(
            try resolverRejected(
                "resolverRevisionBinding",
                descriptor: try descriptor(from: descriptorData) {
                    guard
                        var value = $0["sampling"] as? [String: Any]
                    else {
                        throw ValidationError.invalid("sampling missing")
                    }
                    value["sourceRevisionBinding"] = "source-v17-prepixel"
                    $0["sampling"] = value
                }
            )
        )
        negatives.append(
            try resolverRejected(
                "resolverVariant",
                descriptor: try descriptor(from: descriptorData) {
                    $0["variantID"] = "variant-1"
                }
            )
        )

        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "contract": "CONTRACT-019-R3",
            "disposition": "PASS_PREPIXEL_51_NODE_BOUNDARY",
            "sourceAuthority": false,
            "productionSelected": false,
            "binding": [
                "descriptor": descriptorPath,
                "descriptorSHA256": expectedDescriptorSHA,
                "materialLibrary": materialPath,
                "materialLibrarySHA256": expectedMaterialSHA,
                "sceneGeometryID": candidate.sceneGeometryID,
                "semanticContractID":
                    PLAY027SemanticRendererV1.r3ContractID,
            ],
            "scenePreflight": [
                "nodeCount": nodeNames.count,
                "nodeNamesSHA256": digest(
                    Data(nodeNames.joined(separator: "\n").utf8)
                ),
                "semanticNodeCount": semantic.nodeRecords.count,
                "semanticNodeManifestSHA256":
                    semantic.nodeManifestSHA256,
                "canonicalFoundationCount":
                    nodeNames.filter { $0 == "foundation" }.count,
                "redundantFoundationCount":
                    nodeNames.filter { $0 == "v16-foundation" }.count,
            ],
            "v17SamplingReproduction": true,
            "positive": positiveA.value,
            "negativeCases": negatives,
            "processCounts": [
                "sceneKitMetal": 0,
                "authoritativeRaw": 0,
                "normalizer": 0,
                "siblings": 0,
            ],
            "tool": [
                "validatorSource":
                    "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/ValidateIndustrialL4V18DuplicateFoundationRepair.swift",
                "validatorSourceSHA256": try digest(
                    root.appendingPathComponent(
                        "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/ValidateIndustrialL4V18DuplicateFoundationRepair.swift"
                    )
                ),
                "binarySHA256": try digest(
                    URL(fileURLWithPath: CommandLine.arguments[0])
                ),
            ],
        ]
        var reportData = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        reportData.append(0x0A)
        try FileManager.default.createDirectory(
            at: reportURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try reportData.write(to: reportURL, options: .atomic)
        print("PASS 51-node pre-pixel foundation repair")
        print("negative-count=\(negatives.count)")
    }
}
