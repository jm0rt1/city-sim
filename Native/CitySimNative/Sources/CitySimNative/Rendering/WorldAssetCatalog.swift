import AppKit
import SpriteKit

/// Loads the original repo-owned world atlas through SwiftPM's resource bundle.
/// Textures are cached once and never become simulation or save state.
@MainActor
final class WorldAssetCatalog {
    static let shared = WorldAssetCatalog()

    private var textures: [String: SKTexture] = [:]

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
}
