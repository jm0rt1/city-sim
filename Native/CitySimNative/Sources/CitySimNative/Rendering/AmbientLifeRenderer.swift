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

    /// Creates a bounded corridor vignette plus a truth-safe vacant-land
    /// vegetation base. Every vegetation coordinate remains authoritative
    /// `.empty` state and is kept away from roads, so the landscape cannot read
    /// as an invented street, frontage, plaza, service, or occupied parcel.
    /// Each semantic source is descriptor-driven generated-v4 art. Normal
    /// motion contributes at most two actions; Reduce Motion contributes none.
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
        let roadCoordinates = Set(state.tiles.compactMap {
            $0.kind == .road ? $0.coordinate : nil
        })

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
        addVacantLandscape(
            in: state,
            developedCoordinates: developedCoordinates,
            roadCoordinates: roadCoordinates,
            detail: detail,
            excluding: occupiedVegetationCoordinates,
            to: root
        )
        return root
    }

    private func addVacantLandscape(
        in state: CityGameState,
        developedCoordinates: [GridCoordinate],
        roadCoordinates: Set<GridCoordinate>,
        detail: CameraDetailLevel,
        excluding occupied: Set<GridCoordinate>,
        to root: SKNode
    ) {
        let limit = switch detail {
        case .city: 8
        case .neighborhood: 12
        case .block: 16
        }
        let candidates = state.tiles.compactMap { tile -> GridCoordinate? in
            guard tile.kind == .empty, !occupied.contains(tile.coordinate) else { return nil }
            let roadDistance = roadCoordinates.map {
                abs($0.x - tile.coordinate.x) + abs($0.y - tile.coordinate.y)
            }.min() ?? .max
            let developedDistance = developedCoordinates.map {
                abs($0.x - tile.coordinate.x) + abs($0.y - tile.coordinate.y)
            }.min() ?? .max
            // Field groves are visibly undeveloped landscape, not street trees
            // or implied frontages. Keep them within the developed camera's
            // honest expansion context but outside the road edge.
            guard roadDistance >= 2, developedDistance >= 3, developedDistance <= 8 else {
                return nil
            }
            return tile.coordinate
        }
        let anchors = distributedVacantAnchors(
            from: candidates,
            developedCoordinates: developedCoordinates,
            limit: limit
        )
        guard !anchors.isEmpty else { return }

        let landscape = SKNode()
        landscape.name = "world.environment.vacant-landscape"
        for coordinate in anchors {
            let semanticName = "world.environment.vacant-grove.\(coordinate.x).\(coordinate.y)"
            guard let grove = generatedDecoration(
                logicalID: "ambient_vegetation_cluster",
                semanticName: semanticName,
                detail: detail,
                position: style.isoPosition(coordinate),
                zPosition: style.depth(for: coordinate) + 46
            ) else { continue }
            let meadow = SKShapeNode(path: style.diamondPath(width: 48, height: 24))
            meadow.name = "\(semanticName).undeveloped-meadow"
            meadow.fillColor = NSColor(
                calibratedRed: 0.28,
                green: 0.43,
                blue: 0.22,
                alpha: 0.34
            )
            meadow.strokeColor = style.palette.mapEarthDark.withAlphaComponent(0.16)
            meadow.lineWidth = 0.7
            meadow.position = CGPoint(x: -1, y: -3)
            meadow.zPosition = -2
            grove.addChild(meadow)
            let contact = SKShapeNode(ellipseOf: CGSize(width: 31, height: 9))
            contact.name = "\(semanticName).ground-contact"
            contact.fillColor = NSColor.black.withAlphaComponent(0.16)
            contact.strokeColor = .clear
            contact.position = CGPoint(x: 2, y: -5)
            contact.zPosition = -1
            grove.addChild(contact)
            let scale = 0.62 + 0.16 * WorldVisualSeed.unit(
                for: coordinate,
                kind: .empty,
                salt: 0x6A24
            )
            grove.setScale(scale)
            landscape.addChild(grove)
        }
        if !landscape.children.isEmpty {
            root.addChild(landscape)
        }
    }

    private func distributedVacantAnchors(
        from candidates: [GridCoordinate],
        developedCoordinates: [GridCoordinate],
        limit: Int
    ) -> [GridCoordinate] {
        guard limit > 0, !candidates.isEmpty else { return [] }
        let ordered = candidates.sorted { lhs, rhs in
            let lhsDistance = developedCoordinates.map { developed in
                abs(developed.x - lhs.x) + abs(developed.y - lhs.y)
            }.min() ?? .max
            let rhsDistance = developedCoordinates.map { developed in
                abs(developed.x - rhs.x) + abs(developed.y - rhs.y)
            }.min() ?? .max
            if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
            let lhsSeed = WorldVisualSeed.value(for: lhs, kind: .empty, salt: 0x6A25)
            let rhsSeed = WorldVisualSeed.value(for: rhs, kind: .empty, salt: 0x6A25)
            if lhsSeed == rhsSeed { return (lhs.y, lhs.x) < (rhs.y, rhs.x) }
            return lhsSeed < rhsSeed
        }
        var selected: [GridCoordinate] = []
        for candidate in ordered where selected.count < min(limit, ordered.count) {
            guard selected.allSatisfy({
                abs($0.x - candidate.x) + abs($0.y - candidate.y) >= 2
            }) else { continue }
            selected.append(candidate)
        }
        if selected.count < min(limit, ordered.count) {
            for candidate in ordered where selected.count < min(limit, ordered.count) {
                guard !selected.contains(candidate) else { continue }
                selected.append(candidate)
            }
        }
        return selected
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
