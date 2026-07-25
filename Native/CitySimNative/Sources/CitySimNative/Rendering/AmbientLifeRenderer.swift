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

        var furnitureByRoadIndex: [Int: SKNode] = [:]
        if detail.includes(.neighborhood) {
            let preferredRoadOrder = Array(roads.indices.dropFirst(2)) + Array(roads.indices.prefix(2))
            for roadIndex in preferredRoadOrder where furnitureByRoadIndex.count < 3 {
                let road = roads[roadIndex]
                if let furniture = streetFurniture(
                    at: road.coordinate,
                    index: furnitureByRoadIndex.count,
                    in: state,
                    position: style.isoPosition(road.coordinate)
                ) {
                    furnitureByRoadIndex[roadIndex] = furniture
                }
            }
        }

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

            if let furniture = furnitureByRoadIndex[index] {
                vignette.addChild(furniture)
            }

            if let coordinate = vegetationCoordinate(
                in: state,
                near: road.coordinate,
                excluding: occupiedVegetationCoordinates
            ), let cluster = generatedDecoration(
                logicalID: "ambient_vegetation_cluster",
                semanticName: "world.ambient.vegetation-cluster.\(index)",
                detail: detail,
                position: vegetationPosition(for: coordinate, salt: 0x6A11),
                zPosition: style.depth(for: coordinate) + 48
            ) {
                occupiedVegetationCoordinates.insert(coordinate)
                addVegetationComposition(
                    to: cluster,
                    coordinate: coordinate,
                    semanticName: "world.ambient.vegetation-cluster.\(index)",
                    detail: detail,
                    salt: 0x6A12
                )
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
        // Keep one semantic set across camera changes. Generated-v4 source
        // detail and the terrain material layers provide LOD meaning; changing
        // entity quantity would defeat incremental reuse and residency.
        let limit = 16
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
                position: vegetationPosition(for: coordinate, salt: 0x6A26),
                zPosition: style.depth(for: coordinate) + 46
            ) else { continue }
            let composition = WorldVisualSeed.variant(
                count: 3,
                for: coordinate,
                kind: .empty,
                salt: 0x6A27
            )
            let meadow = SKShapeNode(path: meadowSwatchPath(variant: composition))
            meadow.name = "\(semanticName).undeveloped-meadow"
            meadow.fillColor = NSColor(
                calibratedRed: 0.28,
                green: 0.43,
                blue: 0.22,
                alpha: 0.18
            )
            meadow.strokeColor = .clear
            meadow.position = CGPoint(x: -1, y: -3)
            meadow.zPosition = -2
            grove.addChild(meadow)
            let compositionIdentity = SKNode()
            compositionIdentity.name = "\(semanticName).composition.\(composition)"
            grove.addChild(compositionIdentity)
            addVegetationComposition(
                to: grove,
                coordinate: coordinate,
                semanticName: semanticName,
                detail: detail,
                salt: 0x6A27
            )
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

    private func vegetationPosition(for coordinate: GridCoordinate, salt: UInt64) -> CGPoint {
        let center = style.isoPosition(coordinate)
        let horizontal = WorldVisualSeed.unit(
            for: coordinate,
            kind: .empty,
            salt: salt
        )
        let vertical = WorldVisualSeed.unit(
            for: coordinate,
            kind: .empty,
            salt: salt &+ 1
        )
        return CGPoint(
            x: center.x + (horizontal * 16 - 8),
            y: center.y + (vertical * 6 - 3)
        )
    }

    private func meadowSwatchPath(variant: Int) -> CGPath {
        let points: [CGPoint]
        switch variant {
        case 1:
            points = [
                CGPoint(x: -23, y: -1),
                CGPoint(x: -15, y: 7),
                CGPoint(x: -2, y: 10),
                CGPoint(x: 18, y: 6),
                CGPoint(x: 23, y: -2),
                CGPoint(x: 8, y: -9),
                CGPoint(x: -12, y: -7),
            ]
        case 2:
            points = [
                CGPoint(x: -21, y: 2),
                CGPoint(x: -9, y: 10),
                CGPoint(x: 9, y: 8),
                CGPoint(x: 24, y: 1),
                CGPoint(x: 14, y: -8),
                CGPoint(x: -5, y: -10),
                CGPoint(x: -24, y: -4),
            ]
        default:
            points = [
                CGPoint(x: -24, y: 0),
                CGPoint(x: -13, y: 9),
                CGPoint(x: 5, y: 8),
                CGPoint(x: 22, y: 3),
                CGPoint(x: 17, y: -7),
                CGPoint(x: -1, y: -9),
                CGPoint(x: -18, y: -6),
            ]
        }
        return WorldGeometryCache.polygon(points)
    }

    private func addVegetationComposition(
        to root: SKNode,
        coordinate: GridCoordinate,
        semanticName: String,
        detail: CameraDetailLevel,
        salt: UInt64
    ) {
        let composition = WorldVisualSeed.variant(
            count: 3,
            for: coordinate,
            kind: .empty,
            salt: salt
        )
        guard let primary = root.children.first as? SKSpriteNode else { return }
        primary.position.x += composition == 1 ? -4 : composition == 2 ? 5 : 0

        let companions: [(position: CGPoint, scale: CGFloat)]
        switch composition {
        case 1:
            companions = [(CGPoint(x: 13, y: -4), 0.52)]
        case 2:
            companions = [
                (CGPoint(x: -12, y: -4), 0.46),
                (CGPoint(x: -3, y: 4), 0.34),
            ]
        default:
            companions = []
        }
        for (index, companion) in companions.enumerated() {
            guard let sprite = assets.generatedSprite(
                logicalID: "ambient_vegetation_cluster",
                detail: detail
            ) else { continue }
            sprite.name = "\(semanticName).companion.\(index).generated-v4.\(detail.assetSuffix)"
            sprite.position = companion.position
            sprite.setScale(companion.scale)
            sprite.zPosition = CGFloat(index) - 1
            root.addChild(sprite)
        }
    }

    private func streetFurniture(
        at coordinate: GridCoordinate,
        index: Int,
        in state: CityGameState,
        position roadPosition: CGPoint
    ) -> SKNode? {
        let connections = RoadConnectionMask.resolving(at: coordinate, in: state)
        let orderedEdges = connections.edges
        guard !orderedEdges.isEmpty else { return nil }
        let variant = index % 3
        let preferredSide: CGFloat = WorldVisualSeed.unit(
            for: coordinate,
            kind: .road,
            salt: 0x57A33
        ) < 0.5 ? -1 : 1
        let orderedSides = [preferredSide, -preferredSide]
        let orderedCandidates = orderedEdges.flatMap { edge in
            orderedSides.map { side in (edge: edge, side: side) }
        }
        guard let placement = orderedCandidates.first(where: {
            isClearSidewalkPlacement(
                edge: $0.edge,
                side: $0.side,
                connections: connections
            )
        }) else { return nil }

        let endpoint = style.roadSocket(for: placement.edge)
        let endpointLength = max(0.001, hypot(endpoint.x, endpoint.y))
        let direction = CGPoint(x: endpoint.x / endpointLength, y: endpoint.y / endpointLength)
        let perpendicular = CGPoint(x: -direction.y, y: direction.x)
        let localCenter = CGPoint(
            x: endpoint.x * 0.50 + perpendicular.x * 11.25 * placement.side,
            y: endpoint.y * 0.50 + perpendicular.y * 11.25 * placement.side
        )
        let root = SKNode()
        let identity: String
        switch variant {
        case 1: identity = "stone-planter"
        case 2: identity = "cycle-rack"
        default: identity = "wood-bench"
        }
        root.name = "world.public-realm.street-furniture.\(identity).\(coordinate.x).\(coordinate.y)"
        root.position = CGPoint(
            x: roadPosition.x + localCenter.x,
            y: roadPosition.y + localCenter.y
        )
        root.zRotation = atan2(direction.y, direction.x)
        root.zPosition = style.depth(for: coordinate) + 55

        let contact = SKShapeNode(path: WorldGeometryCache.polygon([
            CGPoint(x: -6, y: 0),
            CGPoint(x: -3, y: 1.25),
            CGPoint(x: 6, y: 0),
            CGPoint(x: 3, y: -1.25),
        ]))
        contact.name = "\(root.name ?? "world.public-realm.street-furniture").ground-contact"
        contact.fillColor = NSColor.black.withAlphaComponent(0.14)
        contact.strokeColor = .clear
        contact.position.y = -1.5
        root.addChild(contact)

        switch variant {
        case 1:
            addStonePlanter(to: root)
        case 2:
            addCycleRack(to: root)
        default:
            addWoodBench(to: root)
        }
        root.setScale(0.72)
        return root
    }

    private func isClearSidewalkPlacement(
        edge: RoadConnectionMask,
        side: CGFloat,
        connections: RoadConnectionMask
    ) -> Bool {
        let endpoint = style.roadSocket(for: edge)
        let endpointLength = max(0.001, hypot(endpoint.x, endpoint.y))
        let direction = CGPoint(x: endpoint.x / endpointLength, y: endpoint.y / endpointLength)
        let perpendicular = CGPoint(x: -direction.y, y: direction.x)
        let center = CGPoint(
            x: endpoint.x * 0.50 + perpendicular.x * 11.25 * side,
            y: endpoint.y * 0.50 + perpendicular.y * 11.25 * side
        )
        let alongOffsets: [CGFloat] = [-6, 6]
        let acrossOffsets: [CGFloat] = [-1.25, 1.25]
        var corners: [CGPoint] = []
        for along in alongOffsets {
            for across in acrossOffsets {
                let alongPoint = CGPoint(
                    x: direction.x * along,
                    y: direction.y * along
                )
                let acrossPoint = CGPoint(
                    x: perpendicular.x * across,
                    y: perpendicular.y * across
                )
                corners.append(CGPoint(
                    x: center.x + alongPoint.x + acrossPoint.x,
                    y: center.y + alongPoint.y + acrossPoint.y
                ))
            }
        }
        return corners.allSatisfy { point in
            let normalizedX = abs(point.x) / (style.tileWidth / 2)
            let normalizedY = abs(point.y) / (style.tileHeight / 2)
            let insideRoadTile = normalizedX + normalizedY <= 0.96
            let outsideEveryRoadCore = connections.edges.allSatisfy { connection in
                pointSegmentDistance(point, end: style.roadSocket(for: connection)) >= 9.1
            }
            let awayFromSockets = connections.edges.allSatisfy { connection in
                let socket = style.roadSocket(for: connection)
                return hypot(point.x - socket.x, point.y - socket.y) >= 3.0
            }
            return insideRoadTile && outsideEveryRoadCore && awayFromSockets
        }
    }

    private func pointSegmentDistance(_ point: CGPoint, end: CGPoint) -> CGFloat {
        let lengthSquared = end.x * end.x + end.y * end.y
        guard lengthSquared > 0 else { return hypot(point.x, point.y) }
        let projection = min(1, max(0, (point.x * end.x + point.y * end.y) / lengthSquared))
        let closest = CGPoint(x: end.x * projection, y: end.y * projection)
        return hypot(point.x - closest.x, point.y - closest.y)
    }

    private func addWoodBench(to root: SKNode) {
        let seat = SKShapeNode(path: WorldGeometryCache.polygon([
            CGPoint(x: -6, y: 1),
            CGPoint(x: -3, y: 2.6),
            CGPoint(x: 6, y: 1),
            CGPoint(x: 3, y: -0.6),
        ]))
        seat.name = "\(root.name ?? "world.public-realm.street-furniture").seat"
        seat.fillColor = NSColor(calibratedRed: 0.33, green: 0.22, blue: 0.13, alpha: 1)
        seat.strokeColor = NSColor(calibratedRed: 0.16, green: 0.12, blue: 0.09, alpha: 0.75)
        seat.lineWidth = 0.7
        seat.position.y = 2
        root.addChild(seat)

        let back = SKShapeNode(path: WorldGeometryCache.polygon([
            CGPoint(x: -5.5, y: 3),
            CGPoint(x: -3, y: 4.3),
            CGPoint(x: 5.5, y: 3),
            CGPoint(x: 3, y: 1.7),
        ]))
        back.fillColor = NSColor(calibratedRed: 0.39, green: 0.26, blue: 0.15, alpha: 1)
        back.strokeColor = NSColor.white.withAlphaComponent(0.12)
        back.lineWidth = 0.5
        back.position.y = 3
        root.addChild(back)

        for x in [-3.5, 3.5] {
            let leg = SKShapeNode(rectOf: CGSize(width: 1.1, height: 3.5), cornerRadius: 0.3)
            leg.fillColor = style.palette.roofDark
            leg.strokeColor = .clear
            leg.position = CGPoint(x: x, y: 0)
            root.addChild(leg)
        }
    }

    private func addStonePlanter(to root: SKNode) {
        let base = SKShapeNode(path: WorldGeometryCache.polygon([
            CGPoint(x: -5.5, y: 1),
            CGPoint(x: -3, y: 3),
            CGPoint(x: 5.5, y: 1),
            CGPoint(x: 4, y: -2.5),
            CGPoint(x: -4, y: -2.5),
        ]))
        base.name = "\(root.name ?? "world.public-realm.street-furniture").basin"
        base.fillColor = NSColor(calibratedWhite: 0.38, alpha: 1)
        base.strokeColor = style.palette.concreteLight.withAlphaComponent(0.52)
        base.lineWidth = 0.7
        base.position.y = 1
        root.addChild(base)

        for (index, x) in [-3.5, 0.0, 3.5].enumerated() {
            let leaf = SKShapeNode(path: WorldGeometryCache.polygon([
                CGPoint(x: 0, y: 0),
                CGPoint(x: -2.2, y: 4.8 + CGFloat(index % 2)),
                CGPoint(x: 0.4, y: 7.5 + CGFloat(index)),
                CGPoint(x: 2.1, y: 3.5),
            ]))
            leaf.fillColor = NSColor(
                calibratedRed: 0.12 + CGFloat(index) * 0.02,
                green: 0.26 + CGFloat(index) * 0.025,
                blue: 0.16,
                alpha: 0.94
            )
            leaf.strokeColor = NSColor(calibratedRed: 0.06, green: 0.14, blue: 0.08, alpha: 0.72)
            leaf.lineWidth = 0.45
            leaf.position = CGPoint(x: x, y: 3)
            root.addChild(leaf)
        }
    }

    private func addCycleRack(to root: SKNode) {
        let railPath = CGMutablePath()
        for x in [-4.0, 0.0, 4.0] {
            railPath.move(to: CGPoint(x: x - 2, y: 0))
            railPath.addLine(to: CGPoint(x: x - 2, y: 5))
            railPath.addLine(to: CGPoint(x: x, y: 7))
            railPath.addLine(to: CGPoint(x: x + 2, y: 5))
            railPath.addLine(to: CGPoint(x: x + 2, y: 0))
        }
        let rack = SKShapeNode(path: railPath)
        rack.name = "\(root.name ?? "world.public-realm.street-furniture").rail"
        rack.strokeColor = style.palette.roofDark.withAlphaComponent(0.78)
        rack.lineWidth = 0.9
        rack.lineCap = .round
        rack.position.y = 0.5
        root.addChild(rack)

        let highlight = SKShapeNode(path: WorldGeometryCache.line(
            from: CGPoint(x: -6, y: 1.5),
            to: CGPoint(x: 6, y: 1.5)
        ))
        highlight.strokeColor = NSColor.white.withAlphaComponent(0.08)
        highlight.lineWidth = 0.4
        root.addChild(highlight)
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
