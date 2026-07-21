import SpriteKit

/// Adds one bounded, truth-safe ambient vignette without asserting traffic,
/// occupancy, employment, prosperity, or service coverage.
@MainActor
final class AmbientLifeRenderer {
    private let style: WorldVisualStyle
    private let assets: WorldAssetCatalog

    init(style: WorldVisualStyle, assets: WorldAssetCatalog) {
        self.style = style
        self.assets = assets
    }

    /// Creates one corridor vignette for the whole visible city: exactly one
    /// pedestrian pair, one parked maintenance object, and one vegetation
    /// cluster. Each semantic source is descriptor-driven generated-v4 art.
    /// Normal motion contributes one action; Reduce Motion contributes none.
    func makeCorridorLife(
        in state: CityGameState,
        detail: CameraDetailLevel,
        reducedMotion: Bool
    ) -> SKNode {
        let root = SKNode()
        root.name = "world.ambient.corridor"

        let completed = state.tiles.filter {
            $0.kind != .empty && $0.kind != .road && $0.constructionProgress >= 1
        }
        let developedCoordinates = completed.map(\.coordinate)
        guard !developedCoordinates.isEmpty else { return root }

        let road = state.tiles.filter { tile in
            tile.kind == .road && state.neighbors(of: tile.coordinate).contains {
                $0.kind != .empty && $0.kind != .road && $0.constructionProgress >= 1
            }
        }.min { lhs, rhs in
            let lhsDistance = developedCoordinates.reduce(0) {
                $0 + abs($1.x - lhs.coordinate.x) + abs($1.y - lhs.coordinate.y)
            }
            let rhsDistance = developedCoordinates.reduce(0) {
                $0 + abs($1.x - rhs.coordinate.x) + abs($1.y - rhs.coordinate.y)
            }
            if lhsDistance == rhsDistance {
                return (lhs.coordinate.y, lhs.coordinate.x) < (rhs.coordinate.y, rhs.coordinate.x)
            }
            return lhsDistance < rhsDistance
        }
        guard let road else { return root }

        let roadPosition = style.isoPosition(road.coordinate)
        if let pair = generatedDecoration(
            logicalID: "ambient_pedestrian_pair",
            semanticName: "world.ambient.pedestrian-pair",
            detail: detail,
            position: CGPoint(x: roadPosition.x + 4, y: roadPosition.y + 15),
            zPosition: style.depth(for: road.coordinate) + 58
        ) {
            if !reducedMotion {
                let phase = Double(WorldVisualSeed.unit(
                    for: road.coordinate,
                    kind: .road,
                    salt: 0xC0111D0
                )) * 0.8
                let stroll = SKAction.sequence([
                    .moveBy(x: 4, y: -2, duration: 2.4),
                    .moveBy(x: -4, y: 2, duration: 2.4),
                ])
                pair.run(
                    .sequence([.wait(forDuration: phase), .repeatForever(stroll)]),
                    withKey: "ambient.corridor.walk"
                )
            }
            root.addChild(pair)
        }

        if let service = generatedDecoration(
            logicalID: "ambient_service_object",
            semanticName: "world.ambient.parked-service-object",
            detail: detail,
            position: CGPoint(x: roadPosition.x - 17, y: roadPosition.y - 2),
            zPosition: style.depth(for: road.coordinate) + 56
        ) {
            root.addChild(service)
        }

        if let coordinate = vegetationCoordinate(in: state, near: road.coordinate),
           let cluster = generatedDecoration(
               logicalID: "ambient_vegetation_cluster",
               semanticName: "world.ambient.vegetation-cluster",
               detail: detail,
               position: style.isoPosition(coordinate),
               zPosition: style.depth(for: coordinate) + 48
           ) {
            root.addChild(cluster)
        }
        return root
    }

    private func generatedDecoration(
        logicalID: String,
        semanticName: String,
        detail: CameraDetailLevel,
        position: CGPoint,
        zPosition: CGFloat
    ) -> SKNode? {
        guard let sprite = assets.generatedSprite(logicalID: logicalID, detail: detail) else {
            return nil
        }
        let root = SKNode()
        root.name = semanticName
        root.position = position
        root.zPosition = zPosition
        sprite.name = "\(semanticName).generated-v4.\(detail.assetSuffix)"
        root.addChild(sprite)
        return root
    }

    private func vegetationCoordinate(in state: CityGameState, near road: GridCoordinate) -> GridCoordinate? {
        state.tiles.filter { tile in
            guard tile.kind == .empty else { return false }
            let distance = abs(tile.coordinate.x - road.x) + abs(tile.coordinate.y - road.y)
            return distance == 1 || distance == 2
        }.sorted {
            let lhsDistance = abs($0.coordinate.x - road.x) + abs($0.coordinate.y - road.y)
            let rhsDistance = abs($1.coordinate.x - road.x) + abs($1.coordinate.y - road.y)
            if lhsDistance == rhsDistance {
                return ($0.coordinate.y, $0.coordinate.x) < ($1.coordinate.y, $1.coordinate.x)
            }
            return lhsDistance < rhsDistance
        }.first?.coordinate
    }
}
