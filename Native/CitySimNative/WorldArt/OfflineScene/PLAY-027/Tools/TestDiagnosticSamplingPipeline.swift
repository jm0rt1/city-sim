import Foundation

enum DiagnosticSamplingPipelineTestError: Error {
    case failed(String)
}

@main
enum TestDiagnosticSamplingPipelineMain {
    static func main() throws {
        let root = URL(
            fileURLWithPath: "/tmp/play027-diagnostic-sampling-test",
            isDirectory: true
        )
        let validOutput = root.appendingPathComponent(
            "docs/production/evidence/PLAY-027/sampling/diagnostics/"
                + "run-a/output.png"
        )
        let validRecord = validOutput.deletingLastPathComponent()
            .appendingPathComponent("record.json")
        let legacy = DescriptorSamplingResolver.legacySchema1

        guard
            try DiagnosticSamplingPipelineContract.resolve(
                requestedContractID: nil,
                repositoryRoot: root,
                outputURL: root.appendingPathComponent("default.png"),
                recordURL: root.appendingPathComponent("default.json"),
                descriptorSHA256: String(repeating: "a", count: 64),
                rendererSourceCommit: "67646d5",
                productionSelected: false,
                explicitAntialiasing: nil,
                explicitSceneShadows: nil,
                explicitMaterialLighting: nil,
                diagnosticContractID: nil,
                diagnosticStageContractID: nil,
                descriptorSampling: legacy
            ) == nil
        else {
            throw DiagnosticSamplingPipelineTestError.failed(
                "nil option changed the default renderer path"
            )
        }

        let valid = try DiagnosticSamplingPipelineContract.resolve(
            requestedContractID:
                DiagnosticSamplingPipelineContract.contractID,
            repositoryRoot: root,
            outputURL: validOutput,
            recordURL: validRecord,
            descriptorSHA256: String(repeating: "b", count: 64),
            rendererSourceCommit: "67646d5",
            productionSelected: false,
            explicitAntialiasing: nil,
            explicitSceneShadows: nil,
            explicitMaterialLighting: nil,
            diagnosticContractID: nil,
            diagnosticStageContractID: nil,
            descriptorSampling: legacy
        )
        guard
            valid?.effectiveSampling.sceneKitAntialiasing == "none",
            valid?.effectiveSampling.linearOversamplingFactor == 4,
            valid?.effectiveSampling.downsampleScale == 0.25,
            valid?.effectiveSampling.quantizerID == legacy.quantizerID,
            valid?.effectiveSampling.canonicalizerID
                == legacy.canonicalizerID,
            valid?.effectiveSampling.postQuantizationCanonicalizer
                == legacy.postQuantizationCanonicalizer
        else {
            throw DiagnosticSamplingPipelineTestError.failed(
                "valid diagnostic pipeline did not preserve downstream contracts"
            )
        }

        struct InvalidCase {
            let label: String
            let id: String?
            let output: URL
            let record: URL
            let selected: Bool
            let antialiasing: String?
            let shadows: String?
            let lighting: String?
            let isolation: String?
            let stage: String?
            let descriptorSHA: String
            let sourceCommit: String
        }
        let invalidCases = [
            InvalidCase(
                label: "unknown mode",
                id: "unknown",
                output: validOutput,
                record: validRecord,
                selected: false,
                antialiasing: nil,
                shadows: nil,
                lighting: nil,
                isolation: nil,
                stage: nil,
                descriptorSHA: String(repeating: "b", count: 64),
                sourceCommit: "67646d5"
            ),
            InvalidCase(
                label: "output outside diagnostics",
                id: DiagnosticSamplingPipelineContract.contractID,
                output: root.appendingPathComponent("output.png"),
                record: validRecord,
                selected: false,
                antialiasing: nil,
                shadows: nil,
                lighting: nil,
                isolation: nil,
                stage: nil,
                descriptorSHA: String(repeating: "b", count: 64),
                sourceCommit: "67646d5"
            ),
            InvalidCase(
                label: "record outside diagnostics",
                id: DiagnosticSamplingPipelineContract.contractID,
                output: validOutput,
                record: root.appendingPathComponent("record.json"),
                selected: false,
                antialiasing: nil,
                shadows: nil,
                lighting: nil,
                isolation: nil,
                stage: nil,
                descriptorSHA: String(repeating: "b", count: 64),
                sourceCommit: "67646d5"
            ),
            InvalidCase(
                label: "independent antialiasing override",
                id: DiagnosticSamplingPipelineContract.contractID,
                output: validOutput,
                record: validRecord,
                selected: false,
                antialiasing: "none",
                shadows: nil,
                lighting: nil,
                isolation: nil,
                stage: nil,
                descriptorSHA: String(repeating: "b", count: 64),
                sourceCommit: "67646d5"
            ),
            InvalidCase(
                label: "independent shadow override",
                id: DiagnosticSamplingPipelineContract.contractID,
                output: validOutput,
                record: validRecord,
                selected: false,
                antialiasing: nil,
                shadows: "current",
                lighting: nil,
                isolation: nil,
                stage: nil,
                descriptorSHA: String(repeating: "b", count: 64),
                sourceCommit: "67646d5"
            ),
            InvalidCase(
                label: "diagnostic contract collision",
                id: DiagnosticSamplingPipelineContract.contractID,
                output: validOutput,
                record: validRecord,
                selected: false,
                antialiasing: nil,
                shadows: nil,
                lighting: nil,
                isolation: "other",
                stage: nil,
                descriptorSHA: String(repeating: "b", count: 64),
                sourceCommit: "67646d5"
            ),
            InvalidCase(
                label: "production selected",
                id: DiagnosticSamplingPipelineContract.contractID,
                output: validOutput,
                record: validRecord,
                selected: true,
                antialiasing: nil,
                shadows: nil,
                lighting: nil,
                isolation: nil,
                stage: nil,
                descriptorSHA: String(repeating: "b", count: 64),
                sourceCommit: "67646d5"
            ),
            InvalidCase(
                label: "missing descriptor hash",
                id: DiagnosticSamplingPipelineContract.contractID,
                output: validOutput,
                record: validRecord,
                selected: false,
                antialiasing: nil,
                shadows: nil,
                lighting: nil,
                isolation: nil,
                stage: nil,
                descriptorSHA: "short",
                sourceCommit: "67646d5"
            ),
        ]
        for invalid in invalidCases {
            do {
                _ = try DiagnosticSamplingPipelineContract.resolve(
                    requestedContractID: invalid.id,
                    repositoryRoot: root,
                    outputURL: invalid.output,
                    recordURL: invalid.record,
                    descriptorSHA256: invalid.descriptorSHA,
                    rendererSourceCommit: invalid.sourceCommit,
                    productionSelected: invalid.selected,
                    explicitAntialiasing: invalid.antialiasing,
                    explicitSceneShadows: invalid.shadows,
                    explicitMaterialLighting: invalid.lighting,
                    diagnosticContractID: invalid.isolation,
                    diagnosticStageContractID: invalid.stage,
                    descriptorSampling: legacy
                )
                throw DiagnosticSamplingPipelineTestError.failed(
                    "\(invalid.label) was not rejected"
                )
            } catch is DiagnosticSamplingPipelineError {
                continue
            }
        }

        print(
            "PASS diagnostic sampling option is fail-closed; "
                + "nil invocation preserves the legacy sampling contract"
        )
    }
}
