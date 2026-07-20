import AppKit
import SpriteKit

/// Adds bounded, decorative motion without asserting traffic, employment,
/// service coverage, or any other simulation fact.
@MainActor
final class AmbientLifeRenderer {
    private let style: WorldVisualStyle

    init(style: WorldVisualStyle) {
        self.style = style
    }

    func makeAmbientVegetation(
        for tile: CityTile,
        detail: CameraDetailLevel,
        reducedMotion: Bool
    ) -> SKNode? {
        guard tile.kind == .park || tile.kind == .residential else { return nil }

        let root = SKNode()
        root.name = "lot.ambient.vegetation"
        let neighborhood = style.makeDetailLayer(.neighborhood, visibleAt: detail)
        root.addChild(neighborhood)

        let drift = SKNode()
        drift.name = "lot.ambient.leafDrift"
        let side: CGFloat = WorldVisualSeed.variant(
            count: 2,
            for: tile.coordinate,
            kind: tile.kind,
            salt: 0xA11F
        ) == 0 ? -1 : 1
        drift.position = CGPoint(x: side * 22, y: 18)

        for index in 0..<3 {
            let leaf = SKShapeNode(ellipseOf: CGSize(width: 3.6, height: 1.8))
            leaf.fillColor = index.isMultiple(of: 2)
                ? NSColor(calibratedRed: 0.59, green: 0.75, blue: 0.34, alpha: 0.82)
                : NSColor(calibratedRed: 0.86, green: 0.69, blue: 0.25, alpha: 0.78)
            leaf.strokeColor = .clear
            leaf.position = CGPoint(x: CGFloat(index * 6 - 6), y: CGFloat(index % 2) * 4)
            leaf.zRotation = CGFloat(index - 1) * 0.35
            drift.addChild(leaf)
        }

        if !reducedMotion {
            let phase = Double(WorldVisualSeed.unit(
                for: tile.coordinate,
                kind: tile.kind,
                salt: 0xA11F
            )) * 1.2
            let loop = SKAction.sequence([
                .group([
                    .moveBy(x: side * 4, y: 2, duration: 1.8),
                    .rotate(byAngle: side * 0.12, duration: 1.8)
                ]),
                .group([
                    .moveBy(x: side * -4, y: -2, duration: 1.8),
                    .rotate(byAngle: side * -0.12, duration: 1.8)
                ])
            ])
            drift.run(
                .sequence([.wait(forDuration: phase), .repeatForever(loop)]),
                withKey: "ambient.vegetation"
            )
        }

        neighborhood.addChild(drift)
        return root
    }
}
