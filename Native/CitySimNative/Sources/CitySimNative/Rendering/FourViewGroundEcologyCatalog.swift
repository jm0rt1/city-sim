import AppKit
import SpriteKit

struct FourViewGroundEcologyManifest: Decodable, Equatable, Sendable {
    struct Canvas: Decodable, Equatable, Sendable {
        let width: Int
        let height: Int
        let footprintPivotPixel: [Int]
    }

    struct Asset: Decodable, Equatable, Sendable {
        let assetID: String
        let file: String
        let sha256: String
        let role: String
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
final class FourViewGroundEcologyCatalog {
    static let shared = FourViewGroundEcologyCatalog()

    static let sourceTileSize = CGSize(width: 88, height: 44)
    static let sourceCanvasSize = CGSize(width: 384, height: 384)
    static let footprintPivotTopOrigin = CGPoint(x: 192, y: 300)
    static let spriteAnchor = CGPoint(x: 0.5, y: 84.0 / 384.0)

    static let requiredAssetIDs: Set<String> = [
        "civic_meadow_ground",
        "worn_neighborhood_ground",
        "park_grove_ground",
        "utility_service_ground",
        "maple_street_tree",
        "sage_shrub_cluster",
        "marigold_planter_cluster",
    ]
    static let requiredRolesByAssetID: [String: String] = [
        "civic_meadow_ground": "ground-treatment",
        "worn_neighborhood_ground": "ground-treatment",
        "park_grove_ground": "ground-treatment",
        "utility_service_ground": "ground-treatment",
        "maple_street_tree": "vegetation-dressing",
        "sage_shrub_cluster": "vegetation-dressing",
        "marigold_planter_cluster": "vegetation-dressing",
    ]

    let manifest: FourViewGroundEcologyManifest?
    private let bundle: Bundle
    private let assetsByID: [String: FourViewGroundEcologyManifest.Asset]
    private var textures: [String: SKTexture] = [:]

    init(bundle: Bundle = CityResourceBundle.shared) {
        self.bundle = bundle
        let loaded = Self.loadManifest(from: bundle)
        if let loaded, Self.isCanonical(loaded) {
            self.manifest = loaded
            self.assetsByID = Dictionary(
                uniqueKeysWithValues: loaded.assets.map { ($0.assetID, $0) }
            )
        } else {
            self.manifest = nil
            self.assetsByID = [:]
        }
    }

    func groundAssetID(for tile: CityTile) -> String? {
        switch tile.kind {
        case .residential:
            "worn_neighborhood_ground"
        case .commercial, .cityHall, .fireStation, .policeStation, .school:
            "worn_neighborhood_ground"
        case .industrial, .powerPlant, .waterTower:
            "utility_service_ground"
        case .park:
            "park_grove_ground"
        case .empty:
            "civic_meadow_ground"
        case .road:
            nil
        }
    }

    func makeGroundSprite(for tile: CityTile, worldTileWidth: CGFloat) -> SKSpriteNode? {
        guard let assetID = groundAssetID(for: tile) else { return nil }
        return makeSprite(assetID: assetID, worldTileWidth: worldTileWidth, zPosition: -4)
    }

    func makeSprite(
        assetID: String,
        worldTileWidth: CGFloat,
        zPosition: CGFloat = 0
    ) -> SKSpriteNode? {
        guard let descriptor = assetsByID[assetID],
              let texture = texture(for: descriptor) else {
            return nil
        }
        let sprite = SKSpriteNode(texture: texture, size: Self.sourceCanvasSize)
        sprite.anchorPoint = Self.spriteAnchor
        sprite.setScale(worldTileWidth / Self.sourceTileSize.width)
        sprite.zPosition = zPosition

        let sourceIdentity = SKNode()
        sourceIdentity.name = "ground-ecology.four-view.\(assetID).camNE"
        sprite.addChild(sourceIdentity)
        return sprite
    }

    func resourceURL(for assetID: String) -> URL? {
        guard let file = assetsByID[assetID]?.file else { return nil }
        return bundle.url(
            forResource: (file as NSString).deletingPathExtension,
            withExtension: (file as NSString).pathExtension,
            subdirectory: "FourViewGroundEcologyAssets"
        )
    }

    private func texture(for descriptor: FourViewGroundEcologyManifest.Asset) -> SKTexture? {
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

    private static func loadManifest(from bundle: Bundle) -> FourViewGroundEcologyManifest? {
        guard let url = bundle.url(
            forResource: "manifest",
            withExtension: "json",
            subdirectory: "FourViewGroundEcologyAssets"
        ), let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(FourViewGroundEcologyManifest.self, from: data)
    }

    private static func isCanonical(_ manifest: FourViewGroundEcologyManifest) -> Bool {
        let assetIDs = manifest.assets.map(\.assetID)
        guard assetIDs.count == Set(assetIDs).count else { return false }
        let rolesByAssetID = Dictionary(
            uniqueKeysWithValues: manifest.assets.map { ($0.assetID, $0.role) }
        )
        return manifest.schema == "citysim.native-four-view-ground-ecology.v1"
            && manifest.camera == "camNE"
            && manifest.cameraAzimuthDegrees == 45
            && manifest.cameraElevationDegrees == 30
            && manifest.projectedTilePixels == [88, 44]
            && manifest.canvas.width == 384
            && manifest.canvas.height == 384
            && manifest.canvas.footprintPivotPixel == [192, 300]
            && manifest.postRenderCompensation == "none"
            && assetIDs.count == requiredAssetIDs.count
            && Set(assetIDs) == requiredAssetIDs
            && rolesByAssetID == requiredRolesByAssetID
    }
}
