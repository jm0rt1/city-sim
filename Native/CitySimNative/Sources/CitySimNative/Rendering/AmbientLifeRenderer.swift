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

    /// Adds one bounded piece of weather-reactive district dressing. The
    /// banner and windsock do not claim shoppers, freight, output, employment,
    /// prosperity, pollution, or service state.
    func makeStrategyDecoration(
        for tile: CityTile,
        detail: CameraDetailLevel,
        reducedMotion: Bool
    ) -> SKNode? {
        guard let identity = StrategyDistrictVisualIdentity(tile: tile) else { return nil }

        let root = SKNode()
        root.name = "lot.ambient.strategy.\(identity.family.rawValue)"
        let block = style.makeDetailLayer(.block, visibleAt: detail)
        root.addChild(block)

        let pole = SKShapeNode(rectOf: CGSize(width: 1.4, height: identity.family == .commercial ? 24 : 30))
        pole.fillColor = NSColor(calibratedWhite: 0.25, alpha: 0.94)
        pole.strokeColor = .clear
        pole.position = CGPoint(x: identity.family == .commercial ? 27 : -28, y: 12)
        pole.name = "lot.ambient.strategy.pole"
        block.addChild(pole)

        let cloth = SKShapeNode(path: style.polygonPath([
            CGPoint(x: 0, y: 4),
            CGPoint(x: identity.family == .commercial ? 15 : 18, y: 0),
            CGPoint(x: identity.family == .commercial ? 12 : 14, y: -6),
            CGPoint(x: 0, y: -3)
        ]))
        cloth.fillColor = identity.family == .commercial
            ? NSColor(calibratedRed: 0.76, green: 0.40, blue: 0.29, alpha: 0.94)
            : NSColor(calibratedRed: 0.88, green: 0.64, blue: 0.22, alpha: 0.94)
        cloth.strokeColor = NSColor.black.withAlphaComponent(0.30)
        cloth.lineWidth = 0.7
        cloth.position = CGPoint(
            x: pole.position.x,
            y: identity.family == .commercial ? 23 : 29
        )
        cloth.name = identity.family == .commercial
            ? "lot.ambient.commercial.banner"
            : "lot.ambient.industrial.windsock"
        block.addChild(cloth)

        if !reducedMotion {
            let phase = Double(WorldVisualSeed.unit(
                for: tile.coordinate,
                kind: tile.kind,
                salt: 0xD157A1C7
            )) * 1.1
            let amplitude: CGFloat = identity.family == .commercial ? 0.055 : 0.085
            let loop = SKAction.sequence([
                .rotate(toAngle: amplitude, duration: 1.4, shortestUnitArc: true),
                .rotate(toAngle: -amplitude, duration: 1.4, shortestUnitArc: true)
            ])
            cloth.run(
                .sequence([.wait(forDuration: phase), .repeatForever(loop)]),
                withKey: "ambient.strategy.weather"
            )
        }
        return root
    }
}
