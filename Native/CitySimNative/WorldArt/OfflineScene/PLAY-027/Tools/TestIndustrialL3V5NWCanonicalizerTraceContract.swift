import Foundation

enum IndustrialL3V5NWCanonicalizerTraceTestError:
    Error,
    CustomStringConvertible
{
    case failed(String)

    var description: String {
        switch self {
        case let .failed(message):
            return message
        }
    }
}

@main
enum TestIndustrialL3V5NWCanonicalizerTraceContractMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard
            let rootIndex = arguments.firstIndex(of: "--repository-root"),
            rootIndex + 1 < arguments.count
        else {
            throw IndustrialL3V5NWCanonicalizerTraceTestError.failed(
                "usage: test --repository-root <path>"
            )
        }
        let repositoryRoot = URL(
            fileURLWithPath: arguments[rootIndex + 1],
            isDirectory: true
        ).standardizedFileURL
        let decoder = JSONDecoder()

        for direction in ["north", "west"] {
            guard
                let authority =
                    IndustrialL3V5NWCanonicalizerTraceContract
                    .directionRecords[direction]
            else {
                throw IndustrialL3V5NWCanonicalizerTraceTestError.failed(
                    "missing direction authority"
                )
            }
            let sceneURL = repositoryRoot.appendingPathComponent(
                authority.scenePath
            )
            let materialsURL = repositoryRoot.appendingPathComponent(
                IndustrialL3V5NWCanonicalizerTraceContract.materialPath
            )
            let descriptor = try decoder.decode(
                SceneDescriptor.self,
                from: Data(contentsOf: sceneURL)
            )
            let sampling = try DescriptorSamplingResolver.resolve(
                descriptor: descriptor
            )
            let traceDirectory = repositoryRoot.appendingPathComponent(
                IndustrialL3V5NWCanonicalizerTraceContract.evidenceRoot
                    + "/\(direction)/run-a"
            )
            let outputURL = traceDirectory.appendingPathComponent("raw.png")
            let recordURL = traceDirectory.appendingPathComponent(
                "provenance.json"
            )

            guard
                try IndustrialL3V5NWCanonicalizerTraceContract.validate(
                    requestedContractID: nil,
                    repositoryRoot: repositoryRoot,
                    sceneURL: sceneURL,
                    sceneSHA256: authority.sceneSHA256,
                    materialsURL: materialsURL,
                    materialSHA256:
                        IndustrialL3V5NWCanonicalizerTraceContract
                        .materialSHA256,
                    outputURL: outputURL,
                    recordURL: recordURL,
                    traceDirectory: nil,
                    descriptor: descriptor,
                    sampling: sampling,
                    explicitAntialiasing: nil,
                    explicitSceneShadows: nil,
                    explicitMaterialLighting: nil,
                    diagnosticSamplingPipelineID: nil,
                    diagnosticContractID: nil,
                    diagnosticStageContractID: nil,
                    diagnosticStageCaptureDirectory: nil,
                    diagnosticStageCoordinate: nil,
                    diagnosticPrequantizedOutput: nil
                ) == nil
            else {
                throw IndustrialL3V5NWCanonicalizerTraceTestError.failed(
                    "default path was not a no-op"
                )
            }

            let valid =
                try IndustrialL3V5NWCanonicalizerTraceContract.validate(
                    requestedContractID:
                        IndustrialL3V5NWCanonicalizerTraceContract
                        .contractID,
                    repositoryRoot: repositoryRoot,
                    sceneURL: sceneURL,
                    sceneSHA256: authority.sceneSHA256,
                    materialsURL: materialsURL,
                    materialSHA256:
                        IndustrialL3V5NWCanonicalizerTraceContract
                        .materialSHA256,
                    outputURL: outputURL,
                    recordURL: recordURL,
                    traceDirectory: traceDirectory,
                    descriptor: descriptor,
                    sampling: sampling,
                    explicitAntialiasing: nil,
                    explicitSceneShadows: nil,
                    explicitMaterialLighting: nil,
                    diagnosticSamplingPipelineID: nil,
                    diagnosticContractID: nil,
                    diagnosticStageContractID: nil,
                    diagnosticStageCaptureDirectory: nil,
                    diagnosticStageCoordinate: nil,
                    diagnosticPrequantizedOutput: nil
                )
            guard
                valid?.direction == direction,
                valid?.coordinates == authority.coordinates,
                valid?.value["canonicalizerChanged"] as? Bool == false
            else {
                throw IndustrialL3V5NWCanonicalizerTraceTestError.failed(
                    "valid trace contract lost frozen authority"
                )
            }

            let invalidCases: [
                (
                    label: String,
                    contractID: String?,
                    sceneSHA: String,
                    traceDirectory: URL?,
                    outputURL: URL,
                    override: String?
                )
            ] = [
                (
                    "unknown contract",
                    "wrong",
                    authority.sceneSHA256,
                    traceDirectory,
                    outputURL,
                    nil
                ),
                (
                    "descriptor hash drift",
                    IndustrialL3V5NWCanonicalizerTraceContract.contractID,
                    String(repeating: "0", count: 64),
                    traceDirectory,
                    outputURL,
                    nil
                ),
                (
                    "outside diagnostics root",
                    IndustrialL3V5NWCanonicalizerTraceContract.contractID,
                    authority.sceneSHA256,
                    repositoryRoot.appendingPathComponent(
                        "docs/production/evidence/PLAY-027/other/"
                            + "\(direction)/run-a"
                    ),
                    repositoryRoot.appendingPathComponent(
                        "docs/production/evidence/PLAY-027/other/"
                            + "\(direction)/run-a/raw.png"
                    ),
                    nil
                ),
                (
                    "sampling override",
                    IndustrialL3V5NWCanonicalizerTraceContract.contractID,
                    authority.sceneSHA256,
                    traceDirectory,
                    outputURL,
                    "none"
                ),
            ]
            for candidate in invalidCases {
                do {
                    _ =
                        try IndustrialL3V5NWCanonicalizerTraceContract
                            .validate(
                                requestedContractID:
                                    candidate.contractID,
                                repositoryRoot: repositoryRoot,
                                sceneURL: sceneURL,
                                sceneSHA256: candidate.sceneSHA,
                                materialsURL: materialsURL,
                                materialSHA256:
                                    IndustrialL3V5NWCanonicalizerTraceContract
                                    .materialSHA256,
                                outputURL: candidate.outputURL,
                                recordURL:
                                    candidate.traceDirectory?
                                    .appendingPathComponent(
                                        "provenance.json"
                                    ) ?? recordURL,
                                traceDirectory:
                                    candidate.traceDirectory,
                                descriptor: descriptor,
                                sampling: sampling,
                                explicitAntialiasing:
                                    candidate.override,
                                explicitSceneShadows: nil,
                                explicitMaterialLighting: nil,
                                diagnosticSamplingPipelineID: nil,
                                diagnosticContractID: nil,
                                diagnosticStageContractID: nil,
                                diagnosticStageCaptureDirectory: nil,
                                diagnosticStageCoordinate: nil,
                                diagnosticPrequantizedOutput: nil
                            )
                    throw IndustrialL3V5NWCanonicalizerTraceTestError
                        .failed(
                            "\(candidate.label) was not rejected"
                        )
                } catch is
                    IndustrialL3V5NWCanonicalizerTraceContractError
                {
                    continue
                }
            }
        }

        print(
            "PASS Industrial L3 source-v05 North/West trace contract; "
                + "exact diagnostic roots accepted, drift and overrides fail closed"
        )
    }
}
