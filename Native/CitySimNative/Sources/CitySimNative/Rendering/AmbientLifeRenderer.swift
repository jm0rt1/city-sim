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

    /// Creates a bounded five-anchor corridor vignette for the visible city:
    /// two pedestrian pairs, one parked maintenance object, and five
    /// vegetation clusters. Each semantic source is descriptor-driven
    /// generated-v4 art. Normal motion contributes at most two actions;
    /// Reduce Motion contributes none.
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

        let candidateRoads = state.tiles.filter { tile in
            guard tile.kind == .road else { return false }
            let distance = developedCoordinates.map {
                abs($0.x - tile.coordinate.x) + abs($0.y - tile.coordinate.y)
            }.min() ?? .max
            return distance <= 4
        }
        let roads = corridorAnchors(
            from: candidateRoads,
            developedCoordinates: developedCoordinates,
            limit: 5
        )
        guard !roads.isEmpty else { return root }

        var occupiedVegetationCoordinates: Set<GridCoordinate> = []
        for (index, road) in roads.enumerated() {
            let roadPosition = style.isoPosition(road.coordinate)
            let vignette = SKNode()
            vignette.name = "world.ambient.vignette.\(index)"

            if index < 2, let pair = generatedDecoration(
                logicalID: "ambient_pedestrian_pair",
                semanticName: "world.ambient.pedestrian-pair.\(index)",
                detail: detail,
                position: CGPoint(x: roadPosition.x + 4, y: roadPosition.y + 15),
                zPosition: style.depth(for: road.coordinate) + 58
            ) {
                if !reducedMotion {
                    let phase = Double(WorldVisualSeed.unit(
                        for: road.coordinate,
                        kind: .road,
                        salt: 0xC0111D0 + UInt64(index)
                    )) * 0.8
                    let direction: CGFloat = index.isMultiple(of: 2) ? 1 : -1
                    let stroll = SKAction.sequence([
                        .moveBy(x: 4 * direction, y: -2 * direction, duration: 2.4),
                        .moveBy(x: -4 * direction, y: 2 * direction, duration: 2.4),
                    ])
                    // Opening life is visible but finite so pausing and settling
                    // releases animation residency.
                    pair.run(
                        .sequence([.wait(forDuration: phase), .repeat(stroll, count: 3)]),
                        withKey: "ambient.corridor.walk"
                    )
                }
                vignette.addChild(pair)
            }

            if index == 1, let service = generatedDecoration(
                logicalID: "ambient_service_object",
                semanticName: "world.ambient.parked-service-object",
                detail: detail,
                position: CGPoint(x: roadPosition.x - 17, y: roadPosition.y - 2),
                zPosition: style.depth(for: road.coordinate) + 56
            ) {
                vignette.addChild(service)
            }

            if let coordinate = vegetationCoordinate(
                in: state,
                near: road.coordinate,
                excluding: occupiedVegetationCoordinates
            ), let cluster = generatedDecoration(
                logicalID: "ambient_vegetation_cluster",
                semanticName: "world.ambient.vegetation-cluster.\(index)",
                detail: detail,
                position: style.isoPosition(coordinate),
                zPosition: style.depth(for: coordinate) + 48
            ) {
                occupiedVegetationCoordinates.insert(coordinate)
                let scale = 0.84 + 0.16 * WorldVisualSeed.unit(
                    for: coordinate,
                    kind: .empty,
                    salt: 0x6A10
                )
                cluster.setScale(scale)
                vignette.addChild(cluster)
            }
            if !vignette.children.isEmpty {
                root.addChild(vignette)
            }
        }
        return root
    }

    private func corridorAnchors(
        from roads: [CityTile],
        developedCoordinates: [GridCoordinate],
        limit: Int
    ) -> [CityTile] {
        guard !roads.isEmpty, limit > 0 else { return [] }
        let ordered = roads.sorted { lhs, rhs in
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
        // Seed two lived-in frontage anchors before spreading the remaining
        // public-realm rhythm along the authoritative network.
        var selected = Array(ordered.prefix(min(2, limit)))
        while selected.count < min(limit, ordered.count) {
            let remaining = ordered.filter { candidate in
                !selected.contains { $0.coordinate == candidate.coordinate }
            }
            guard let next = remaining.max(by: { lhs, rhs in
                let lhsSeparation = selected.map {
                    abs($0.coordinate.x - lhs.coordinate.x)
                        + abs($0.coordinate.y - lhs.coordinate.y)
                }.min() ?? 0
                let rhsSeparation = selected.map {
                    abs($0.coordinate.x - rhs.coordinate.x)
                        + abs($0.coordinate.y - rhs.coordinate.y)
                }.min() ?? 0
                if lhsSeparation == rhsSeparation {
                    return (lhs.coordinate.y, lhs.coordinate.x)
                        > (rhs.coordinate.y, rhs.coordinate.x)
                }
                return lhsSeparation < rhsSeparation
            }) else { break }
            selected.append(next)
        }
        return selected
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

    private func vegetationCoordinate(
        in state: CityGameState,
        near road: GridCoordinate,
        excluding occupied: Set<GridCoordinate>
    ) -> GridCoordinate? {
        state.tiles.filter { tile in
            guard tile.kind == .empty, !occupied.contains(tile.coordinate) else { return false }
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
