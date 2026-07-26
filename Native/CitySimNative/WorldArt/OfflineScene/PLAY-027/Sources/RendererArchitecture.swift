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
    let sceneKitShadows: String
    let sceneKitLightingMode: String
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
    let preLanczosCanonicalizer:
        SamplingPreLanczosCanonicalizerDescriptor?
    let postQuantizationCanonicalizer:
        SamplingPostQuantizationCanonicalizerDescriptor?
    let purpose: String
}

enum DescriptorSamplingResolver {
    static let legacySchema1 = EffectiveSamplingContract(
        contractID: "play027-legacy-schema1-factor2-msaa4x-v1",
        descriptorSchema: 1,
        sceneKitAntialiasing: "multisampling4X",
        sceneKitShadows: "current",
        sceneKitLightingMode: "lambert-scene-lights",
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
        preLanczosCanonicalizer: nil,
        postQuantizationCanonicalizer: nil,
        purpose: "accepted-legacy-reproduction"
    )

    static let schema2ContractV1ID =
        "play027-deterministic-4x-no-msaa-lanczos-v1"
    static let schema2ContractV2ID =
        "play027-deterministic-4x-no-msaa-lanczos-v2"
    static let schema2ContractV3ID =
        "play027-deterministic-4x-no-msaa-lanczos-v3"

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
        let isV1 = sampling.contractID == schema2ContractV1ID
        let isV2 = sampling.contractID == schema2ContractV2ID
        let isV3 = sampling.contractID == schema2ContractV3ID
        let sceneKitShadows = sampling.sceneKitShadows ?? "current"
        let sceneKitLightingMode =
            sampling.sceneKitLightingMode ?? "lambert-scene-lights"
        let isIndustrialL2SourceV04 =
            descriptor.logicalBuildingID == "industrial_l02"
            && descriptor.sourceRevision == "source-v04"
            && sampling.purpose == "source-authority"
        let isIndustrialL2SourceV05 =
            descriptor.logicalBuildingID == "industrial_l02"
            && descriptor.sourceRevision == "source-v05"
            && sampling.purpose == "source-authority"
        let isIndustrialL2SourceV06East =
            descriptor.logicalBuildingID == "industrial_l02"
            && descriptor.sourceRevision == "source-v06"
            && descriptor.viewDirection == "east"
            && sampling.purpose == "source-authority"
        let isIndustrialL2SourceV07East =
            descriptor.logicalBuildingID == "industrial_l02"
            && descriptor.sourceRevision == "source-v07"
            && descriptor.viewDirection == "east"
            && sampling.purpose == "source-authority"
        let isIndustrialL2AuthoredConstant =
            isIndustrialL2SourceV05
            || isIndustrialL2SourceV06East
            || isIndustrialL2SourceV07East
        let isIndustrialL3SourceV02 =
            descriptor.logicalBuildingID == "industrial_l03"
            && descriptor.sourceRevision == "source-v02"
            && ["north", "east", "south", "west"].contains(
                descriptor.viewDirection
            )
            && sampling.purpose == "source-authority"
            && isV3
        let isAuthoredConstantSource =
            isIndustrialL2AuthoredConstant
            || isIndustrialL3SourceV02
        guard
            isV1 || isV2 || isV3,
            sampling.sourceRevisionBinding == descriptor.sourceRevision,
            ["diagnostic-regression", "source-authority"].contains(
                sampling.purpose
            ),
            sampling.sceneKitAntialiasing == "none",
            ["current", "disabled"].contains(sceneKitShadows),
            [
                "lambert-scene-lights",
                "authored-constant-v1",
            ].contains(sceneKitLightingMode),
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
        guard
            (
                (
                    isIndustrialL2SourceV04
                        || isAuthoredConstantSource
                )
                    && sceneKitShadows == "disabled"
            )
                || (
                    !isIndustrialL2SourceV04
                    && !isAuthoredConstantSource
                    && sceneKitShadows == "current")
        else {
            throw SamplingContractError.invalid(
                "SceneKit shadows may be disabled only by the enumerated Industrial L2 revisions or Industrial L3 source-v02 N/E/S/W v3 source-authority descriptors"
            )
        }
        guard
            (
                isAuthoredConstantSource
                    && sceneKitLightingMode == "authored-constant-v1"
            )
                || (
                    !isAuthoredConstantSource
                    && sceneKitLightingMode == "lambert-scene-lights"
                )
        else {
            throw SamplingContractError.invalid(
                "authored-constant-v1 may be selected only by the enumerated Industrial L2 revisions or Industrial L3 source-v02 N/E/S/W v3 source-authority descriptors"
            )
        }
        if isIndustrialL2SourceV07East {
            guard
                let preLanczos =
                    sampling.preLanczosCanonicalizer,
                preLanczos.algorithm
                    == "rgb-step32-midpoint8-preserve-alpha-chroma-v1",
                preLanczos.version == 1,
                preLanczos.quantizationStep == 32,
                preLanczos.midpointOffset == 8,
                preLanczos.chromaBypassRGBA == [255, 0, 255, 255],
                preLanczos.channels == "rgb-only",
                preLanczos.opaquePixelPolicy
                    == "quantize-each-rgb-channel",
                preLanczos.transparentPixelPolicy
                    == "zero-hidden-rgb",
                preLanczos.partialAlphaPolicy == "reject",
                preLanczos.preservesAlpha,
                preLanczos.preservesChroma,
                preLanczos.immutableSourceBuffer,
                preLanczos.crossRunState == "none"
            else {
                throw SamplingContractError.invalid(
                    "Industrial L2 source-v07 East pre-Lanczos canonicalizer mismatch"
                )
            }
        } else if sampling.preLanczosCanonicalizer != nil {
            throw SamplingContractError.invalid(
                "pre-Lanczos canonicalization is authorized only for Industrial L2 source-v07 East"
            )
        }
        if isV1, sampling.postQuantizationCanonicalizer != nil {
            throw SamplingContractError.invalid(
                "schema-2 contract v1 must omit post-quantization canonicalization"
            )
        }
        if isV2 {
            guard
                let repair =
                    sampling.postQuantizationCanonicalizer,
                repair.algorithm
                    == "opaque-isolated-one-quantum-majority-3x3",
                repair.version == 2,
                repair.quantizationQuantum == 32,
                repair.neighborhoodSize == 3,
                repair.majorityThreshold == 7,
                repair.requiresFullyOpaqueNeighborhood,
                repair.immutableSourceBuffer,
                repair.requiresChromaFreeNeighborhood,
                repair.channels == "rgb-only",
                repair.preservesAlpha,
                repair.preservesChroma,
                repair.boundaryAssist == nil
            else {
                throw SamplingContractError.invalid(
                    "schema-2 contract v2 post-quantization canonicalizer mismatch"
                )
            }
        }
        if isV3 {
            guard
                let repair =
                    sampling.postQuantizationCanonicalizer,
                repair.algorithm
                    == "opaque-isolated-one-quantum-majority-3x3",
                repair.version == 3,
                repair.quantizationQuantum == 32,
                repair.neighborhoodSize == 3,
                repair.majorityThreshold == 7,
                repair.requiresFullyOpaqueNeighborhood,
                repair.immutableSourceBuffer,
                repair.requiresChromaFreeNeighborhood,
                repair.channels == "rgb-only",
                repair.preservesAlpha,
                repair.preservesChroma,
                let assist = repair.boundaryAssist,
                assist.algorithm
                    == "immutable-prequantized-one-value-boundary-6-plus-1",
                assist.version == 1,
                assist.baseQuantizedMajorityCount == 6,
                assist.requiredBoundaryVoteCount == 1,
                assist.effectiveSupportCount == 7,
                assist
                    .maximumCompetingSupportAfterBoundaryReclassification
                    == 2,
                assist.quantizerStep == sampling.quantizer.step,
                assist.quantizerMidpointOffset
                    == sampling.quantizer.midpointOffset,
                assist.boundaryBandWidthValues == 1,
                assist.requiresSameChannelEvidence,
                assist.immutablePrequantizedBuffer,
                assist.recordsBoundaryVoteReason
            else {
                throw SamplingContractError.invalid(
                    "schema-2 contract v3 boundary-assisted canonicalizer mismatch"
                )
            }
        }
        return EffectiveSamplingContract(
            contractID: sampling.contractID,
            descriptorSchema: descriptor.schema,
            sceneKitAntialiasing: sampling.sceneKitAntialiasing,
            sceneKitShadows: sceneKitShadows,
            sceneKitLightingMode: sceneKitLightingMode,
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
            preLanczosCanonicalizer:
                sampling.preLanczosCanonicalizer,
            postQuantizationCanonicalizer:
                sampling.postQuantizationCanonicalizer,
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
