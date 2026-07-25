import CoreGraphics
import CoreImage
import Foundation
import ModelIO
import SceneKit

enum OfflineRenderStage: String, CaseIterable {
    case validateDescriptor
    case buildModelIOMeshes
    case assembleSceneKitGraph
    case renderOversampledOrthographicSource
    case downsampleWithCoreImage
    case registerAndCompositeWithCoreGraphics
    case writeDeterministicPNGAndRecord
}

struct OfflineRenderContract {
    static let sourceCanvasPixels = CGSize(width: 1536, height: 1024)
    static let sourceDiamondPixels = CGSize(width: 512, height: 256)
    static let native2xTileDiamondPixels = CGSize(width: 144, height: 72)
    static let flatChromaRGBA = [255, 0, 255, 255]
    static let permittedFrameworks = [
        "SceneKit",
        "ModelIO",
        "CoreImage",
        "CoreGraphics",
    ]
    static let productionSelected = false
}

enum SamplingContractError: Error, CustomStringConvertible {
    case invalid(String)

    var description: String {
        switch self {
        case let .invalid(message):
            return message
        }
    }
}

struct EffectiveSamplingContract: Equatable {
    let contractID: String
    let descriptorSchema: Int
    let sceneKitAntialiasing: String
    let linearOversamplingFactor: Int
    let downsampleFilter: String
    let downsampleScale: Double
    let downsampleAspectRatio: Double
    let ciUseSoftwareRenderer: Bool
    let ciCacheIntermediates: Bool
    let ciWorkingColorSpace: String
    let ciOutputColorSpace: String
    let quantizerID: String
    let quantizerStep: Int
    let quantizerMidpointOffset: Int
    let chromaBypassRGBA: [Int]
    let canonicalizerID: String
    let canonicalizerEncoder: String
    let canonicalizerPostEncoder: String
    let canonicalizerFormat: String
    let purpose: String
}

enum DescriptorSamplingResolver {
    static let legacySchema1 = EffectiveSamplingContract(
        contractID: "play027-legacy-schema1-factor2-msaa4x-v1",
        descriptorSchema: 1,
        sceneKitAntialiasing: "multisampling4X",
        linearOversamplingFactor: 2,
        downsampleFilter: "CILanczosScaleTransform",
        downsampleScale: 0.5,
        downsampleAspectRatio: 1,
        ciUseSoftwareRenderer: true,
        ciCacheIntermediates: false,
        ciWorkingColorSpace: "extended-srgb",
        ciOutputColorSpace: "srgb",
        quantizerID: "step32-midpoint-offset8-v1",
        quantizerStep: 32,
        quantizerMidpointOffset: 8,
        chromaBypassRGBA: [255, 0, 255, 255],
        canonicalizerID: "imageio-sips-png-v1",
        canonicalizerEncoder: "ImageIO",
        canonicalizerPostEncoder: "/usr/bin/sips",
        canonicalizerFormat: "png",
        purpose: "accepted-legacy-reproduction"
    )

    static let schema2ContractID =
        "play027-deterministic-4x-no-msaa-lanczos-v1"

    static func resolve(
        descriptor: SceneDescriptor
    ) throws -> EffectiveSamplingContract {
        if descriptor.schema == 1 {
            guard
                descriptor.sampling == nil,
                descriptor.camera.oversamplingFactor
                    == legacySchema1.linearOversamplingFactor
            else {
                throw SamplingContractError.invalid(
                    "schema 1 must omit sampling and retain factor-2 legacy sampling"
                )
            }
            return legacySchema1
        }
        guard descriptor.schema == 2, let sampling = descriptor.sampling else {
            throw SamplingContractError.invalid(
                "only schema 1 legacy or schema 2 explicit sampling is supported"
            )
        }
        guard
            sampling.contractID == schema2ContractID,
            sampling.sourceRevisionBinding == descriptor.sourceRevision,
            ["diagnostic-regression", "source-authority"].contains(
                sampling.purpose
            ),
            sampling.sceneKitAntialiasing == "none",
            sampling.linearOversamplingFactor == 4,
            descriptor.camera.oversamplingFactor == 4,
            sampling.downsample.filter == "CILanczosScaleTransform",
            sampling.downsample.scale == 0.25,
            sampling.downsample.aspectRatio == 1,
            sampling.ciContext.useSoftwareRenderer,
            !sampling.ciContext.cacheIntermediates,
            sampling.ciContext.workingColorSpace == "extended-srgb",
            sampling.ciContext.outputColorSpace == "srgb",
            sampling.quantizer.id == "step32-midpoint-offset8-v1",
            sampling.quantizer.step == 32,
            sampling.quantizer.midpointOffset == 8,
            sampling.quantizer.chromaBypassRGBA == [255, 0, 255, 255],
            sampling.canonicalizer.id == "imageio-sips-png-v1",
            sampling.canonicalizer.encoder == "ImageIO",
            sampling.canonicalizer.postEncoder == "/usr/bin/sips",
            sampling.canonicalizer.format == "png"
        else {
            throw SamplingContractError.invalid(
                "schema 2 sampling block does not match the frozen deterministic contract"
            )
        }
        return EffectiveSamplingContract(
            contractID: sampling.contractID,
            descriptorSchema: descriptor.schema,
            sceneKitAntialiasing: sampling.sceneKitAntialiasing,
            linearOversamplingFactor: sampling.linearOversamplingFactor,
            downsampleFilter: sampling.downsample.filter,
            downsampleScale: sampling.downsample.scale,
            downsampleAspectRatio: sampling.downsample.aspectRatio,
            ciUseSoftwareRenderer:
                sampling.ciContext.useSoftwareRenderer,
            ciCacheIntermediates:
                sampling.ciContext.cacheIntermediates,
            ciWorkingColorSpace:
                sampling.ciContext.workingColorSpace,
            ciOutputColorSpace:
                sampling.ciContext.outputColorSpace,
            quantizerID: sampling.quantizer.id,
            quantizerStep: sampling.quantizer.step,
            quantizerMidpointOffset:
                sampling.quantizer.midpointOffset,
            chromaBypassRGBA:
                sampling.quantizer.chromaBypassRGBA,
            canonicalizerID: sampling.canonicalizer.id,
            canonicalizerEncoder: sampling.canonicalizer.encoder,
            canonicalizerPostEncoder:
                sampling.canonicalizer.postEncoder,
            canonicalizerFormat: sampling.canonicalizer.format,
            purpose: sampling.purpose
        )
    }
}

protocol OfflineSceneBuilding {
    func buildScene(from descriptor: SceneDescriptor) throws -> SCNScene
}

protocol OfflineSourceRendering {
    func renderSource(
        scene: SCNScene,
        descriptor: SceneDescriptor
    ) throws -> CGImage
}

protocol OfflineSourceCompositing {
    func compositeRegisteredSource(
        renderedImage: CGImage,
        descriptor: SceneDescriptor
    ) throws -> CGImage
}

struct RendererArchitectureFingerprint: Codable {
    let stages: [String]
    let sourceCanvasPixels: [Int]
    let sourceDiamondPixels: [Int]
    let native2xTileDiamondPixels: [Int]
    let flatChromaRGBA: [Int]
    let permittedFrameworks: [String]
    let productRuntimeDependency: Bool
    let packageManifestChange: Bool
    let productionSelected: Bool

    static let frozen = RendererArchitectureFingerprint(
        stages: OfflineRenderStage.allCases.map(\.rawValue),
        sourceCanvasPixels: [1536, 1024],
        sourceDiamondPixels: [512, 256],
        native2xTileDiamondPixels: [144, 72],
        flatChromaRGBA: OfflineRenderContract.flatChromaRGBA,
        permittedFrameworks: OfflineRenderContract.permittedFrameworks,
        productRuntimeDependency: false,
        packageManifestChange: false,
        productionSelected: false
    )
}
