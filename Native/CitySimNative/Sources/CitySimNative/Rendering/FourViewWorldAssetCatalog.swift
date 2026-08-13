import AppKit
import SpriteKit

struct FourViewWorldAssetManifest: Decodable, Equatable, Sendable {
    struct Canvas: Decodable, Equatable, Sendable {
        let width: Int
        let height: Int
        let footprintPivotPixel: [Int]
    }

    struct Asset: Decodable, Equatable, Sendable {
        let assetID: String
        let file: String
        let sha256: String
        let roles: [String]
    }

    let schema: String
    let camera: String
    let cameraAzimuthDegrees: Double
    let cameraElevationDegrees: Double
    let projectedTilePixels: [Int]
    let canvas: Canvas
    let postRenderCompensation: String
    let assets: [Asset]
}

@MainActor
final class FourViewWorldAssetCatalog {
    static let shared = FourViewWorldAssetCatalog()

    static let sourceTileSize = CGSize(width: 88, height: 44)
    static let sourceCanvasSize = CGSize(width: 384, height: 384)
    static let footprintPivotTopOrigin = CGPoint(x: 192, y: 300)
    static let spriteAnchor = CGPoint(x: 0.5, y: 84.0 / 384.0)

    let manifest: FourViewWorldAssetManifest?
    private let bundle: Bundle
    private var textures: [String: SKTexture] = [:]

    init(bundle: Bundle = .module) {
        self.bundle = bundle
        self.manifest = Self.loadManifest(from: bundle)
    }

    func assetID(for tile: CityTile, variant: Int) -> String? {
        switch tile.kind {
        case .residential where tile.level >= 2:
            "brickline_rowhouse_apartments"
        case .residential:
            variant.isMultiple(of: 2) ? "marigold_court_house" : "copper_finch_house"
        case .commercial:
            "harbor_corner_storefront"
        case .industrial:
            "ironleaf_service_workshop"
        case .park:
            "pocket_grove_park"
        case .cityHall:
            "hearthside_council_hall"
        case .empty, .road, .powerPlant, .waterTower, .fireStation, .policeStation, .school:
            nil
        }
    }

    func makeSprite(
        for tile: CityTile,
        variant: Int,
        worldTileWidth: CGFloat
    ) -> SKSpriteNode? {
        guard let assetID = assetID(for: tile, variant: variant),
              let descriptor = manifest?.assets.first(where: { $0.assetID == assetID }),
              let texture = texture(for: descriptor) else {
            return nil
        }

        let sprite = SKSpriteNode(texture: texture, size: Self.sourceCanvasSize)
        sprite.anchorPoint = Self.spriteAnchor
        let canonicalWorldScale = worldTileWidth / Self.sourceTileSize.width
        sprite.setScale(canonicalWorldScale)
        sprite.zPosition = 6

        let sourceIdentity = SKNode()
        sourceIdentity.name = "lot.four-view.\(assetID).camNE"
        sprite.addChild(sourceIdentity)
        return sprite
    }

    func resourceURL(for assetID: String) -> URL? {
        guard let file = manifest?.assets.first(where: { $0.assetID == assetID })?.file else {
            return nil
        }
        return bundle.url(
            forResource: (file as NSString).deletingPathExtension,
            withExtension: (file as NSString).pathExtension,
            subdirectory: "FourViewAssets"
        )
    }

    private func texture(for descriptor: FourViewWorldAssetManifest.Asset) -> SKTexture? {
        if let cached = textures[descriptor.assetID] { return cached }
        guard let url = resourceURL(for: descriptor.assetID),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        textures[descriptor.assetID] = texture
        return texture
    }

    private static func loadManifest(from bundle: Bundle) -> FourViewWorldAssetManifest? {
        guard let url = bundle.url(
            forResource: "manifest",
            withExtension: "json",
            subdirectory: "FourViewAssets"
        ), let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(FourViewWorldAssetManifest.self, from: data)
    }
}
