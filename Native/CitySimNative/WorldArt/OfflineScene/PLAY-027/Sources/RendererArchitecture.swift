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
