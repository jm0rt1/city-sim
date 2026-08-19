import AppKit
import SpriteKit

struct FourViewRoadAssetManifest: Decodable, Equatable, Sendable {
    struct Canvas: Decodable, Equatable, Sendable {
        let width: Int
        let height: Int
        let footprintPivotPixel: [Int]
    }

    struct Road: Decodable, Equatable, Sendable {
        let connectionMask: UInt8
        let assetID: String
        let file: String
        let sha256: String
    }

    let schema: String
    let camera: String
    let cameraAzimuthDegrees: Double
    let cameraElevationDegrees: Double
    let projectedTilePixels: [Int]
    let canvas: Canvas
    let postRenderCompensation: String
    let roads: [Road]
}

@MainActor
final class FourViewRoadAssetCatalog {
    static let shared = FourViewRoadAssetCatalog()

    static let sourceTileSize = CGSize(width: 88, height: 44)
    static let sourceCanvasSize = CGSize(width: 384, height: 384)
    static let footprintPivotTopOrigin = CGPoint(x: 192, y: 300)
    static let spriteAnchor = CGPoint(x: 0.5, y: 84.0 / 384.0)

    let manifest: FourViewRoadAssetManifest?
    private let bundle: Bundle
    private let roadsByMask: [UInt8: FourViewRoadAssetManifest.Road]
    private var textures: [UInt8: SKTexture] = [:]

    init(bundle: Bundle = .module) {
        self.bundle = bundle
        let loaded = Self.loadManifest(from: bundle)
        if let loaded, Self.isCanonical(loaded) {
            self.manifest = loaded
            self.roadsByMask = Dictionary(
                uniqueKeysWithValues: loaded.roads.map { ($0.connectionMask, $0) }
            )
        } else {
            self.manifest = nil
            self.roadsByMask = [:]
        }
    }

    func makeSprite(connectionMask: UInt8, worldTileWidth: CGFloat) -> SKSpriteNode? {
        guard let descriptor = roadsByMask[connectionMask],
              let texture = texture(for: descriptor) else {
            return nil
        }

        let sprite = SKSpriteNode(texture: texture, size: Self.sourceCanvasSize)
        sprite.anchorPoint = Self.spriteAnchor
        sprite.setScale(worldTileWidth / Self.sourceTileSize.width)
        sprite.zPosition = 2

        let sourceIdentity = SKNode()
        sourceIdentity.name = String(format: "road.four-view.mask-%02d.camNE", connectionMask)
        sprite.addChild(sourceIdentity)
        return sprite
    }

    func resourceURL(for connectionMask: UInt8) -> URL? {
        guard let file = roadsByMask[connectionMask]?.file else { return nil }
        return bundle.url(
            forResource: (file as NSString).deletingPathExtension,
            withExtension: (file as NSString).pathExtension,
            subdirectory: "FourViewRoadAssets"
        )
    }

    private func texture(for descriptor: FourViewRoadAssetManifest.Road) -> SKTexture? {
        if let cached = textures[descriptor.connectionMask] { return cached }
        guard let url = resourceURL(for: descriptor.connectionMask),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        textures[descriptor.connectionMask] = texture
        return texture
    }

    private static func loadManifest(from bundle: Bundle) -> FourViewRoadAssetManifest? {
        guard let url = bundle.url(
            forResource: "manifest",
            withExtension: "json",
            subdirectory: "FourViewRoadAssets"
        ), let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(FourViewRoadAssetManifest.self, from: data)
    }

    private static func isCanonical(_ manifest: FourViewRoadAssetManifest) -> Bool {
        let masks = manifest.roads.map(\.connectionMask)
        let assetIDs = manifest.roads.map(\.assetID)
        let files = manifest.roads.map(\.file)
        return manifest.schema == "citysim.native-four-view-roads.v1"
            && manifest.camera == "camNE"
            && manifest.cameraAzimuthDegrees == 45
            && manifest.cameraElevationDegrees == 30
            && manifest.projectedTilePixels == [88, 44]
            && manifest.canvas.width == 384
            && manifest.canvas.height == 384
            && manifest.canvas.footprintPivotPixel == [192, 300]
            && manifest.postRenderCompensation == "none"
            && masks.count == 16
            && Set(masks) == Set(UInt8(0)..<16)
            && assetIDs.count == Set(assetIDs).count
            && files.count == Set(files).count
    }
}
