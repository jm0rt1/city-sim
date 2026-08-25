import AppKit
import SpriteKit

struct FourViewWorldAssetManifest: Decodable, Equatable, Sendable {
    struct Canvas: Decodable, Equatable, Sendable {
        let width: Int
        let height: Int
        let footprintPivotPixel: [Int]
    }

    struct Asset: Decodable, Equatable, Sendable {
        struct View: Decodable, Equatable, Sendable {
            let camera: String
            let file: String
            let sha256: String
        }

        let assetID: String
        let file: String
        let sha256: String
        let family: String
        let roles: [String]
        let views: [View]
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
    enum Camera: String, CaseIterable, Sendable {
        case camNE
        case camSE
        case camSW
        case camNW
    }

    static let shared = FourViewWorldAssetCatalog()

    static let canonicalCameraOrder = ["camNE", "camSE", "camSW", "camNW"]

    static let requiredRoles: Set<String> = [
        "residential-low", "residential-medium", "residential-high",
        "commercial-low", "commercial-medium", "commercial-high",
        "industrial-low", "industrial-medium", "industrial-high",
        "city-hall", "park", "power-plant", "water-tower",
        "fire-station", "police-station", "school",
    ]

    static let sourceTileSize = CGSize(width: 88, height: 44)
    static let sourceFootprintTileSpan: CGFloat = 2
    static let sourceFootprintSize = CGSize(
        width: sourceTileSize.width * sourceFootprintTileSpan,
        height: sourceTileSize.height * sourceFootprintTileSpan
    )
    static let sourceCanvasSize = CGSize(width: 384, height: 384)
    static let footprintPivotTopOrigin = CGPoint(x: 192, y: 300)
    static let spriteAnchor = CGPoint(x: 0.5, y: 84.0 / 384.0)

    let manifest: FourViewWorldAssetManifest?
    private let bundle: Bundle
    private var textures: [String: SKTexture] = [:]

    init(bundle: Bundle = .module) {
        self.bundle = bundle
        let loaded = Self.loadManifest(from: bundle)
        self.manifest = if let loaded, Self.isCanonical(loaded) { loaded } else { nil }
    }

    func assetID(for tile: CityTile, variant: Int) -> String? {
        switch tile.kind {
        case .residential where tile.level >= 3:
            deterministicAssetID(forRole: "residential-high", tile: tile, variant: variant)
        case .residential where tile.level == 2:
            deterministicAssetID(forRole: "residential-medium", tile: tile, variant: variant)
        case .residential:
            deterministicAssetID(
                forRole: "residential-low",
                tile: tile,
                variant: max(0, variant - 1)
            )
        case .commercial where tile.level >= 3:
            deterministicAssetID(forRole: "commercial-high", tile: tile, variant: variant)
        case .commercial where tile.level == 2:
            deterministicAssetID(forRole: "commercial-medium", tile: tile, variant: variant)
        case .commercial:
            deterministicAssetID(forRole: "commercial-low", tile: tile, variant: variant)
        case .industrial where tile.level >= 3:
            deterministicAssetID(forRole: "industrial-high", tile: tile, variant: variant)
        case .industrial where tile.level == 2:
            deterministicAssetID(forRole: "industrial-medium", tile: tile, variant: variant)
        case .industrial:
            deterministicAssetID(forRole: "industrial-low", tile: tile, variant: variant)
        case .park:
            deterministicAssetID(forRole: "park", tile: tile, variant: variant)
        case .cityHall:
            deterministicAssetID(forRole: "city-hall", tile: tile, variant: variant)
        case .powerPlant:
            deterministicAssetID(forRole: "power-plant", tile: tile, variant: variant)
        case .waterTower:
            deterministicAssetID(forRole: "water-tower", tile: tile, variant: variant)
        case .fireStation:
            deterministicAssetID(forRole: "fire-station", tile: tile, variant: variant)
        case .policeStation:
            deterministicAssetID(forRole: "police-station", tile: tile, variant: variant)
        case .school:
            deterministicAssetID(forRole: "school", tile: tile, variant: variant)
        case .empty, .road:
            nil
        }
    }

    func assetIDs(forRole role: String) -> [String] {
        manifest?.assets.filter { $0.roles.contains(role) }.map(\.assetID) ?? []
    }

    private func deterministicAssetID(
        forRole role: String,
        tile: CityTile,
        variant: Int
    ) -> String? {
        let candidates = manifest?.assets.filter { $0.roles.contains(role) } ?? []
        guard !candidates.isEmpty else { return nil }
        let index = WorldVisualSeed.variant(
            count: candidates.count,
            for: tile.coordinate,
            kind: tile.kind,
            salt: UInt64(max(0, variant))
        )
        return candidates[index].assetID
    }

    func makeSprite(
        for tile: CityTile,
        variant: Int,
        worldTileWidth: CGFloat,
        camera: Camera = .camNE
    ) -> SKSpriteNode? {
        guard let assetID = assetID(for: tile, variant: variant),
              let descriptor = manifest?.assets.first(where: { $0.assetID == assetID }),
              let texture = texture(for: descriptor, camera: camera) else {
            return nil
        }

        let sprite = SKSpriteNode(texture: texture, size: Self.sourceCanvasSize)
        sprite.anchorPoint = Self.spriteAnchor
        let canonicalWorldScale = worldTileWidth / Self.sourceFootprintSize.width
        sprite.setScale(canonicalWorldScale)
        sprite.zPosition = 6

        let sourceIdentity = SKNode()
        sourceIdentity.name = "lot.four-view.\(assetID).\(camera.rawValue)"
        sprite.addChild(sourceIdentity)
        return sprite
    }

    func resourceURL(for assetID: String, camera: Camera = .camNE) -> URL? {
        guard let descriptor = manifest?.assets.first(where: { $0.assetID == assetID }) else {
            return nil
        }
        let file: String
        if let view = descriptor.views.first(where: { $0.camera == camera.rawValue }) {
            file = view.file
        } else if camera == .camNE {
            file = descriptor.file
        } else {
            return nil
        }
        return bundle.url(
            forResource: (file as NSString).deletingPathExtension,
            withExtension: (file as NSString).pathExtension,
            subdirectory: "FourViewAssets"
        )
    }

    private func texture(
        for descriptor: FourViewWorldAssetManifest.Asset,
        camera: Camera
    ) -> SKTexture? {
        let cacheKey = "\(descriptor.assetID).\(camera.rawValue)"
        if let cached = textures[cacheKey] { return cached }
        guard let url = resourceURL(for: descriptor.assetID, camera: camera),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        textures[cacheKey] = texture
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

    private static func isCanonical(_ manifest: FourViewWorldAssetManifest) -> Bool {
        let assetIDs = manifest.assets.map(\.assetID)
        let files = manifest.assets.flatMap { $0.views.map(\.file) }
        let roles = Set(manifest.assets.flatMap(\.roles))
        let acceptedFamilies: Set<String> = [
            "residential", "commercial", "industrial", "civic-service",
            "utility", "park-landmark",
        ]
        let canonicalCameras = Set(canonicalCameraOrder)
        let viewBindingsAreCanonical = manifest.assets.allSatisfy { asset in
            let cameras = Set(asset.views.map(\.camera))
            guard let primary = asset.views.first(where: { $0.camera == manifest.camera }),
                  primary.file == asset.file,
                  primary.sha256 == asset.sha256 else {
                return false
            }
            return asset.views.count == cameras.count
                && (cameras == [manifest.camera] || cameras == canonicalCameras)
        }
        return manifest.schema == "citysim.native-four-view-assets.v2"
            && manifest.camera == "camNE"
            && manifest.cameraAzimuthDegrees == 45
            && manifest.cameraElevationDegrees == 30
            && manifest.projectedTilePixels == [88, 44]
            && manifest.canvas.width == 384
            && manifest.canvas.height == 384
            && manifest.canvas.footprintPivotPixel == [192, 300]
            && manifest.postRenderCompensation == "none"
            && assetIDs.count == Set(assetIDs).count
            && files.count == Set(files).count
            && viewBindingsAreCanonical
            && manifest.assets.allSatisfy { acceptedFamilies.contains($0.family) }
            && requiredRoles.isSubset(of: roles)
    }
}
