import AppKit
import SpriteKit

struct GoldenDistrictRenderSignature: Equatable {
    let detail: CameraDetailLevel
    let reducedMotion: Bool
}

/// Gate A's deliberately narrow authored district. It is shown only while the
/// authoritative starting core still matches the art; any changed kind,
/// construction stage, density, or condition falls back to the systemic tile
/// renderer rather than allowing a beautiful plate to lie about game state.
@MainActor
final class GoldenDistrictRenderer {
    private let style: WorldVisualStyle
    private let assets: WorldAssetCatalog

    init(style: WorldVisualStyle, assets: WorldAssetCatalog = .shared) {
        self.style = style
        self.assets = assets
    }

    func canPresent(state: CityGameState) -> Bool {
        guard state.gridWidth == 24, state.gridHeight == 24 else { return false }
        let expected: [GridCoordinate: BuildingKind] = [
            GridCoordinate(x: 11, y: 11): .cityHall,
            GridCoordinate(x: 10, y: 11): .residential,
            GridCoordinate(x: 9, y: 11): .residential,
            GridCoordinate(x: 13, y: 11): .commercial,
            GridCoordinate(x: 14, y: 11): .industrial,
            GridCoordinate(x: 11, y: 13): .park,
            GridCoordinate(x: 13, y: 13): .powerPlant,
            GridCoordinate(x: 11, y: 14): .waterTower
        ]
        for (coordinate, kind) in expected {
            guard let tile = state.tile(at: coordinate),
                  tile.kind == kind,
                  tile.level == 1,
                  tile.constructionProgress >= 1,
                  tile.condition >= 0.80 else { return false }
        }
        for x in 4..<20 where state.tile(at: GridCoordinate(x: x, y: 12))?.kind != .road {
            return false
        }
        for y in 8..<17 where state.tile(at: GridCoordinate(x: 12, y: y))?.kind != .road {
            return false
        }
        return true
    }

    func makeDistrict(detail: CameraDetailLevel, reducedMotion: Bool) -> SKNode? {
        let assetName = switch detail {
        case .block: "golden_district_block"
        case .neighborhood: "golden_district_neighborhood"
        case .city: "golden_district_city"
        }
        guard let sprite = assets.sprite(
            named: assetName,
            size: CGSize(width: 368, height: 368 * 2 / 3)
        ) else { return nil }

        let root = SKNode()
        root.name = "world.goldenDistrict"
        root.position = CGPoint(
            x: style.isoPosition(GridCoordinate(x: 12, y: 12)).x,
            y: style.isoPosition(GridCoordinate(x: 12, y: 12)).y + 9
        )
        sprite.name = "world.goldenDistrict.asset.\(detailName(detail))"
        sprite.zPosition = 0
        root.addChild(sprite)
        root.addChild(makeAmbientLife(reducedMotion: reducedMotion))
        return root
    }

    private func makeAmbientLife(reducedMotion: Bool) -> SKNode {
        let pedestrian = SKNode()
        pedestrian.name = "world.goldenDistrict.ambient.pedestrian"
        pedestrian.position = CGPoint(x: 34, y: -72)
        pedestrian.zPosition = 2

        let shadow = SKShapeNode(ellipseOf: CGSize(width: 2.8, height: 1.4))
        shadow.fillColor = NSColor.black.withAlphaComponent(0.28)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 1.4, y: -1.4)
        pedestrian.addChild(shadow)

        let body = SKShapeNode(ellipseOf: CGSize(width: 1.5, height: 3.4))
        body.fillColor = NSColor(calibratedRed: 0.52, green: 0.18, blue: 0.10, alpha: 1)
        body.strokeColor = NSColor(calibratedWhite: 0.12, alpha: 0.45)
        body.lineWidth = 0.25
        body.position.y = 1
        pedestrian.addChild(body)

        if !reducedMotion {
            let stroll = SKAction.sequence([
                .moveBy(x: 8, y: 4, duration: 3.8),
                .wait(forDuration: 1.2),
                .moveBy(x: -8, y: -4, duration: 3.8),
                .wait(forDuration: 1.6)
            ])
            pedestrian.run(.repeatForever(stroll), withKey: "goldenDistrict.stroll")
        }
        return pedestrian
    }

    private func detailName(_ detail: CameraDetailLevel) -> String {
        switch detail {
        case .city: "city"
        case .neighborhood: "neighborhood"
        case .block: "block"
        }
    }
}
