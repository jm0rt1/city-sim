import CoreGraphics
import CoreImage
import Foundation

enum DiagnosticSamplingPipelineError: Error, CustomStringConvertible {
    case invalid(String)

    var description: String {
        switch self {
        case let .invalid(message):
            return message
        }
    }
}

struct DiagnosticSamplingPipelineResolution {
    let effectiveSampling: EffectiveSamplingContract
    let provenance: [String: Any]
}

enum DiagnosticSamplingPipelineContract {
    static let contractID =
        "play027-diagnostics-4x-no-msaa-software-lanczos-v1"
    static let pipelineName = "PLAY-027 offline diagnostic supersampling"
    static let version = 1
    static let filter = "CILanczosScaleTransform"
    static let kernel = "CoreImage.CILanczosScaleTransform"
    static let scale = 0.25
    static let aspectRatio = 1.0
    static let borderPolicy =
        "crop-to-final-1536x1024-extent-without-clamp-or-wrap"
    static let contextMode = "software"
    static let workingColorSpace = "extended-srgb"
    static let outputColorSpace = "srgb"

    private static func relativePath(
        _ url: URL,
        repositoryRoot: URL
    ) -> String? {
        let root = repositoryRoot.standardizedFileURL.path + "/"
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(root) else {
            return nil
        }
        return String(path.dropFirst(root.count))
    }

    static func resolve(
        requestedContractID: String?,
        repositoryRoot: URL,
        outputURL: URL,
        recordURL: URL,
        descriptorSHA256: String,
        rendererSourceCommit: String,
        productionSelected: Bool,
        explicitAntialiasing: String?,
        explicitSceneShadows: String?,
        explicitMaterialLighting: String?,
        diagnosticContractID: String?,
        diagnosticStageContractID: String?,
        descriptorSampling: EffectiveSamplingContract
    ) throws -> DiagnosticSamplingPipelineResolution? {
        guard let requestedContractID else {
            return nil
        }
        guard requestedContractID == contractID else {
            throw DiagnosticSamplingPipelineError.invalid(
                "unknown diagnostic sampling pipeline"
            )
        }
        guard
            productionSelected == false,
            descriptorSHA256.count == 64,
            rendererSourceCommit.count >= 7
        else {
            throw DiagnosticSamplingPipelineError.invalid(
                "diagnostic sampling provenance binding is incomplete"
            )
        }
        guard
            explicitAntialiasing == nil,
            explicitSceneShadows == nil,
            explicitMaterialLighting == nil,
            diagnosticContractID == nil,
            diagnosticStageContractID == nil
        else {
            throw DiagnosticSamplingPipelineError.invalid(
                "diagnostic sampling pipeline rejects independent diagnostic overrides"
            )
        }
        guard
            let outputRelative = relativePath(
                outputURL,
                repositoryRoot: repositoryRoot
            ),
            let recordRelative = relativePath(
                recordURL,
                repositoryRoot: repositoryRoot
            ),
            outputRelative.contains("/diagnostics/"),
            recordRelative.contains("/diagnostics/"),
            outputURL.pathExtension == "png",
            recordURL.pathExtension == "json",
            !FileManager.default.fileExists(atPath: outputURL.path),
            !FileManager.default.fileExists(atPath: recordURL.path)
        else {
            throw DiagnosticSamplingPipelineError.invalid(
                "diagnostic sampling output and record must be new files under a repository diagnostics path"
            )
        }

        let effective = EffectiveSamplingContract(
            contractID: contractID,
            descriptorSchema: descriptorSampling.descriptorSchema,
            sceneKitAntialiasing: "none",
            sceneKitShadows: descriptorSampling.sceneKitShadows,
            sceneKitLightingMode:
                descriptorSampling.sceneKitLightingMode,
            linearOversamplingFactor: 4,
            downsampleFilter: filter,
            downsampleScale: scale,
            downsampleAspectRatio: aspectRatio,
            ciUseSoftwareRenderer: true,
            ciCacheIntermediates: false,
            ciWorkingColorSpace: workingColorSpace,
            ciOutputColorSpace: outputColorSpace,
            quantizerID: descriptorSampling.quantizerID,
            quantizerStep: descriptorSampling.quantizerStep,
            quantizerMidpointOffset:
                descriptorSampling.quantizerMidpointOffset,
            chromaBypassRGBA:
                descriptorSampling.chromaBypassRGBA,
            canonicalizerID: descriptorSampling.canonicalizerID,
            canonicalizerEncoder:
                descriptorSampling.canonicalizerEncoder,
            canonicalizerPostEncoder:
                descriptorSampling.canonicalizerPostEncoder,
            canonicalizerFormat:
                descriptorSampling.canonicalizerFormat,
            preLanczosCanonicalizer:
                descriptorSampling.preLanczosCanonicalizer,
            postQuantizationCanonicalizer:
                descriptorSampling.postQuantizationCanonicalizer,
            purpose: "diagnostic-regression"
        )
        return DiagnosticSamplingPipelineResolution(
            effectiveSampling: effective,
            provenance: [
                "contractID": contractID,
                "pipelineName": pipelineName,
                "version": version,
                "sourceAuthority": false,
                "productionSelected": false,
                "descriptorChanged": false,
                "descriptorSHA256": descriptorSHA256,
                "rendererSourceCommit": rendererSourceCommit,
                "originalSamplingContractID":
                    descriptorSampling.contractID,
                "sceneKitAntialiasing": "none",
                "linearOversamplingFactor": 4,
                "filter": filter,
                "kernel": kernel,
                "scale": scale,
                "aspectRatio": aspectRatio,
                "borderPolicy": borderPolicy,
                "ciContextMode": contextMode,
                "ciCacheIntermediates": false,
                "workingColorSpace": workingColorSpace,
                "outputColorSpace": outputColorSpace,
                "quantizerID": descriptorSampling.quantizerID,
                "canonicalizerID":
                    descriptorSampling.canonicalizerID,
                "finalRegistrationPixels": [1536, 1024],
                "crossRunState": "none",
            ]
        )
    }
}

enum FrozenSoftwareLanczos {
    static func downsample(
        _ image: CGImage,
        sampling: EffectiveSamplingContract,
        outputWidth: Int,
        outputHeight: Int
    ) throws -> CGImage {
        guard
            sampling.downsampleFilter
                == DiagnosticSamplingPipelineContract.filter,
            sampling.downsampleScale > 0,
            sampling.downsampleAspectRatio == 1,
            sampling.ciUseSoftwareRenderer,
            !sampling.ciCacheIntermediates,
            sampling.ciWorkingColorSpace
                == DiagnosticSamplingPipelineContract.workingColorSpace,
            sampling.ciOutputColorSpace
                == DiagnosticSamplingPipelineContract.outputColorSpace,
            outputWidth > 0,
            outputHeight > 0
        else {
            throw DiagnosticSamplingPipelineError.invalid(
                "software Lanczos sampling contract drifted"
            )
        }
        let context = CIContext(options: [
            .useSoftwareRenderer: true,
            .cacheIntermediates: false,
            .workingColorSpace: CGColorSpace(
                name: CGColorSpace.extendedSRGB
            )!,
            .outputColorSpace: CGColorSpace(
                name: CGColorSpace.sRGB
            )!,
        ])
        guard let filter = CIFilter(
            name: DiagnosticSamplingPipelineContract.filter
        ) else {
            throw DiagnosticSamplingPipelineError.invalid(
                "CILanczosScaleTransform unavailable"
            )
        }
        filter.setValue(CIImage(cgImage: image), forKey: kCIInputImageKey)
        filter.setValue(
            sampling.downsampleScale,
            forKey: kCIInputScaleKey
        )
        filter.setValue(
            sampling.downsampleAspectRatio,
            forKey: kCIInputAspectRatioKey
        )
        guard
            let output = filter.outputImage,
            let image = context.createCGImage(
                output,
                from: CGRect(
                    x: 0,
                    y: 0,
                    width: outputWidth,
                    height: outputHeight
                )
            )
        else {
            throw DiagnosticSamplingPipelineError.invalid(
                "software Lanczos downsample failed"
            )
        }
        return image
    }
}
