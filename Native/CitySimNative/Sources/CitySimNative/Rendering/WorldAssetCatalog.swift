import AppKit
import SpriteKit

/// Loads the original repo-owned world atlas through SwiftPM's resource bundle.
/// Textures are cached once and never become simulation or save state.
@MainActor
final class WorldAssetCatalog {
    static let shared = WorldAssetCatalog()

    private var textures: [String: SKTexture] = [:]
    private(set) lazy var generatedManifest: GeneratedWorldAssetManifest? = loadGeneratedManifest()

    private func loadGeneratedManifest() -> GeneratedWorldAssetManifest? {
        guard let url = Bundle.module.url(
            forResource: "generated-v4-manifest",
            withExtension: "json",
            subdirectory: "WorldAssets.atlas"
        ), let data = try? Data(contentsOf: url),
           let manifest = try? JSONDecoder().decode(GeneratedWorldAssetManifest.self, from: data),
           manifest.schema == 4,
           manifest.packID == "generated-v4-calibration" else { return nil }
        return manifest
    }

    func texture(named name: String) -> SKTexture? {
        if let cached = textures[name] { return cached }
        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: "png",
            subdirectory: "WorldAssets.atlas"
        ), let image = NSImage(contentsOf: url) else {
            return nil
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        texture.usesMipmaps = name.hasPrefix("golden_district_") || name.hasPrefix("generated_v4_")
        textures[name] = texture
        return texture
    }

    func sprite(
        named name: String,
        size: CGSize,
        anchorPoint: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) -> SKSpriteNode? {
        guard let texture = texture(named: name) else { return nil }
        let sprite = SKSpriteNode(texture: texture, color: .clear, size: size)
        sprite.anchorPoint = anchorPoint
        sprite.name = "asset.\(name)"
        return sprite
    }

    func generatedSprite(
        logicalID: String,
        detail: CameraDetailLevel
    ) -> SKSpriteNode? {
        guard let asset = generatedManifest?.assets.first(where: { $0.logicalID == logicalID }),
              let lod = asset.lods[detail.assetSuffix],
              asset.worldSize.count == 2,
              asset.anchor.count == 2 else { return nil }
        let name = (lod.file as NSString).deletingPathExtension
        return sprite(
            named: name,
            size: CGSize(width: asset.worldSize[0], height: asset.worldSize[1]),
            anchorPoint: CGPoint(x: asset.anchor[0], y: asset.anchor[1])
        )
    }
}

private extension CameraDetailLevel {
    var assetSuffix: String {
        switch self {
        case .city: "city"
        case .neighborhood: "neighborhood"
        case .block: "block"
        }
    }
}
