import SpriteKit

/// Adds one bounded, truth-safe ambient vignette without asserting traffic,
/// occupancy, employment, prosperity, or service coverage.
@MainActor
final class AmbientLifeRenderer {
    static func presentationBand(for value: Double?) -> UInt8? {
        guard let value else { return nil }
        if value <= 0 { return 0 }
        if value < 1.0 / 3.0 { return 1 }
        if value < 2.0 / 3.0 { return 2 }
        return 3
    }

    enum ActivityDomain: String, Sendable {
        case street
        case place
    }

    struct ActivityPlacement: Equatable, Sendable {
        let domain: ActivityDomain
        let sourceCoordinate: GridCoordinate
        let surfaceCoordinate: GridCoordinate
        let intensity: Double
        let position: CGPoint
        let motionVector: CGPoint
    }

    private enum VacantLandscapeIdentity: Int, CaseIterable {
        case meadow
        case shrubPatch
        case singleGrove
        case asymmetricCopse

        var semanticName: String {
            switch self {
            case .meadow: "meadow"
            case .shrubPatch: "shrub-patch"
            case .singleGrove: "single-grove"
            case .asymmetricCopse: "asymmetric-copse"
            }
        }
    }

    private let style: WorldVisualStyle
    private let assets: WorldAssetCatalog
    private(set) var lastActivityPlacements: [ActivityPlacement] = []

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
        consequences: CitySpatialConsequenceMap,
        detail: CameraDetailLevel,
        reducedMotion: Bool
    ) -> SKNode {
        lastActivityPlacements = []
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
            let vignette = SKNode()
            vignette.name = "world.ambient.vignette.\(index)"

            if let furniture = furnitureByRoadIndex[index] {
                vignette.addChild(furniture)
            }

            // Two authored groves anchor the lived-in corridor. Vacant-land
            // compositions below carry the wider landscape rhythm; repeating
            // this same source at every road vignette reads as a stamped
            // perimeter even when the coordinates and scale differ.
            if (index == 0 || index == 4), let coordinate = vegetationCoordinate(
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
        addLocalActivity(
            in: state,
            consequences: consequences,
            detail: detail,
            reducedMotion: reducedMotion,
            excluding: Set(furnitureByRoadIndex.keys.map { roads[$0].coordinate }),
            to: root
        )
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

    func activityPlacements(
        in state: CityGameState,
        consequences: CitySpatialConsequenceMap,
        detail: CameraDetailLevel,
        excluding excludedRoads: Set<GridCoordinate> = []
    ) -> [ActivityPlacement] {
        activityPlacements(
            in: state,
            detail: detail,
            excluding: excludedRoads,
            streetActivityIndex: { consequences[$0]?.streetActivityIndex },
            placeActivityIndex: { consequences[$0]?.placeActivityIndex }
        )
    }

    func activityPlacements(
        in state: CityGameState,
        detail: CameraDetailLevel,
        excluding excludedRoads: Set<GridCoordinate> = [],
        streetActivityIndex: (GridCoordinate) -> Double?,
        placeActivityIndex: (GridCoordinate) -> Double?
    ) -> [ActivityPlacement] {
        let streetLimit = detail == .city ? 1 : 2
        let placeLimit = 1
        var occupiedSurfaces = excludedRoads
        var placements: [ActivityPlacement] = []

        let streets = state.tiles.compactMap { tile -> (CityTile, Double)? in
            guard tile.kind == .road,
                  !excludedRoads.contains(tile.coordinate),
                  let band = Self.presentationBand(
                    for: streetActivityIndex(tile.coordinate)
                  ),
                  band > 0 else { return nil }
            return (tile, Double(band) / 3)
        }.sorted(by: activityOrder)

        for (tile, intensity) in streets {
            guard placements.filter({ $0.domain == .street }).count < streetLimit,
                  !occupiedSurfaces.contains(tile.coordinate),
                  let geometry = sidewalkActivityGeometry(
                    at: tile.coordinate,
                    in: state,
                    salt: 0xAC7100
                  ) else { continue }
            occupiedSurfaces.insert(tile.coordinate)
            placements.append(ActivityPlacement(
                domain: .street,
                sourceCoordinate: tile.coordinate,
                surfaceCoordinate: tile.coordinate,
                intensity: intensity,
                position: geometry.position,
                motionVector: geometry.motionVector
            ))
        }

        let places = state.tiles.compactMap { tile -> (CityTile, Double)? in
            guard tile.kind != .empty,
                  tile.kind != .road,
                  tile.constructionProgress >= 1,
                  let band = Self.presentationBand(
                    for: placeActivityIndex(tile.coordinate)
                  ),
                  band > 0 else { return nil }
            return (tile, Double(band) / 3)
        }.sorted(by: activityOrder)

        for (tile, intensity) in places {
            guard placements.filter({ $0.domain == .place }).count < placeLimit else {
                break
            }
            let frontages = RoadConnectionMask.resolving(at: tile.coordinate, in: state)
            guard let frontage = ResidentialGeneratedAssetIdentity
                .authoritativeFrontagePriority
                .first(where: frontages.contains) else { continue }
            let delta = frontage.coordinateDelta
            let roadCoordinate = GridCoordinate(
                x: tile.coordinate.x + delta.x,
                y: tile.coordinate.y + delta.y
            )
            guard !occupiedSurfaces.contains(roadCoordinate),
                  state.tile(at: roadCoordinate)?.kind == .road,
                  let geometry = sidewalkActivityGeometry(
                    at: roadCoordinate,
                    in: state,
                    facing: tile.coordinate,
                    salt: 0xAC7200
                  ) else { continue }
            occupiedSurfaces.insert(roadCoordinate)
            placements.append(ActivityPlacement(
                domain: .place,
                sourceCoordinate: tile.coordinate,
                surfaceCoordinate: roadCoordinate,
                intensity: intensity,
                position: geometry.position,
                motionVector: geometry.motionVector
            ))
        }
        return placements
    }

    private func addLocalActivity(
        in state: CityGameState,
        consequences: CitySpatialConsequenceMap,
        detail: CameraDetailLevel,
        reducedMotion: Bool,
        excluding excludedRoads: Set<GridCoordinate>,
        to root: SKNode
    ) {
        let placements = activityPlacements(
            in: state,
            consequences: consequences,
            detail: detail,
            excluding: excludedRoads
        )
        lastActivityPlacements = placements
        guard !placements.isEmpty else { return }

        let activity = SKNode()
        activity.name = "world.activity.local"
        for (index, placement) in placements.enumerated() {
            let semanticName = "world.activity.\(placement.domain.rawValue).local-activity."
                + "\(placement.sourceCoordinate.x).\(placement.sourceCoordinate.y)"
            guard let presence = generatedDecoration(
                logicalID: "ambient_pedestrian_pair",
                semanticName: semanticName,
                detail: detail,
                position: placement.position,
                zPosition: style.depth(for: placement.surfaceCoordinate) + 58
            ) else { continue }
            presence.alpha = 0.50 + CGFloat(placement.intensity) * 0.34
            let scale: CGFloat = switch detail {
            case .city: 0.58
            case .neighborhood: 0.64
            case .block: 0.70
            }
            presence.setScale(scale)
            // The accepted pedestrian descriptor's ground pivot sits 18
            // points below its root. Compensate after scaling so the opaque
            // feet land on the selected outer-sidewalk anchor instead of
            // projecting inward over the drivable road core.
            presence.position.y += 18 * scale
            if !reducedMotion, detail != .city, index < 2 {
                let phase = Double(WorldVisualSeed.unit(
                    for: placement.sourceCoordinate,
                    kind: placement.domain == .street ? .road : .park,
                    salt: 0xAC7300 + UInt64(index)
                )) * 0.8
                let stroll = SKAction.sequence([
                    .moveBy(
                        x: placement.motionVector.x,
                        y: placement.motionVector.y,
                        duration: 2.4
                    ),
                    .moveBy(
                        x: -placement.motionVector.x,
                        y: -placement.motionVector.y,
                        duration: 2.4
                    ),
                ])
                presence.run(
                    .sequence([.wait(forDuration: phase), .repeat(stroll, count: 3)]),
                    withKey: "ambient.local-activity"
                )
            }
            activity.addChild(presence)
        }
        if !activity.children.isEmpty {
            root.addChild(activity)
        }
    }

    private func activityOrder(
        _ lhs: (CityTile, Double),
        _ rhs: (CityTile, Double)
    ) -> Bool {
        if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
        return (lhs.0.coordinate.y, lhs.0.coordinate.x)
            < (rhs.0.coordinate.y, rhs.0.coordinate.x)
    }

    private func sidewalkActivityGeometry(
        at coordinate: GridCoordinate,
        in state: CityGameState,
        facing target: GridCoordinate? = nil,
        salt: UInt64
    ) -> (position: CGPoint, motionVector: CGPoint)? {
        let connections = RoadConnectionMask.resolving(at: coordinate, in: state)
        guard !connections.isEmpty else { return nil }
        let edgeRotation = WorldVisualSeed.variant(
            count: connections.edges.count,
            for: coordinate,
            kind: .road,
            salt: salt
        )
        let orderedEdges = Array(
            connections.edges[edgeRotation...] + connections.edges[..<edgeRotation]
        )
        let preferredSide: CGFloat
        if let target {
            let roadCenter = style.isoPosition(coordinate)
            let targetCenter = style.isoPosition(target)
            let targetVector = CGPoint(
                x: targetCenter.x - roadCenter.x,
                y: targetCenter.y - roadCenter.y
            )
            let edge = orderedEdges[0]
            let endpoint = normalized(style.roadSocket(for: edge))
            let perpendicular = CGPoint(x: -endpoint.y, y: endpoint.x)
            preferredSide = perpendicular.x * targetVector.x + perpendicular.y * targetVector.y >= 0
                ? 1
                : -1
        } else {
            preferredSide = WorldVisualSeed.unit(
                for: coordinate,
                kind: .road,
                salt: salt + 1
            ) < 0.5 ? -1 : 1
        }
        let sides = [preferredSide, -preferredSide]
        for edge in orderedEdges {
            for side in sides where isClearSidewalkPlacement(
                edge: edge,
                side: side,
                connections: connections
            ) {
                let direction = normalized(style.roadSocket(for: edge))
                let perpendicular = CGPoint(x: -direction.y, y: direction.x)
                let center = CGPoint(
                    x: direction.x * style.tileWidth * 0.125
                        + perpendicular.x * 11.25 * side,
                    y: direction.y * style.tileHeight * 0.125
                        + perpendicular.y * 11.25 * side
                )
                let roadCenter = style.isoPosition(coordinate)
                return (
                    position: CGPoint(
                        x: roadCenter.x + center.x,
                        y: roadCenter.y + center.y
                    ),
                    motionVector: CGPoint(
                        x: direction.x * 3.2,
                        y: direction.y * 3.2
                    )
                )
            }
        }
        return nil
    }

    private func addVacantLandscape(
        in state: CityGameState,
        developedCoordinates: [GridCoordinate],
        roadCoordinates: Set<GridCoordinate>,
        detail: CameraDetailLevel,
        excluding occupied: Set<GridCoordinate>,
        to root: SKNode
    ) {
        // Keep one semantic set across camera changes. The bounded set is
        // intentionally sparse: the same generated grove must not become a
        // decorative perimeter stamp around authoritative vacant land.
        let limit = 8
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
        let identities = vacantLandscapeIdentities(for: anchors)

        let landscape = SKNode()
        landscape.name = "world.environment.vacant-landscape"
        for coordinate in anchors {
            guard let identity = identities[coordinate] else { continue }
            let semanticName = "world.environment.vacant-composition."
                + "\(identity.semanticName).\(coordinate.x).\(coordinate.y)"
            let composition = SKNode()
            composition.name = semanticName
            composition.position = vegetationPosition(for: coordinate, salt: 0x6A26)
            composition.zPosition = style.depth(for: coordinate) + 46
            let swatchVariant = WorldVisualSeed.variant(
                count: 3,
                for: coordinate,
                kind: .empty,
                salt: 0x6A28
            )
            let meadow = SKShapeNode(path: meadowSwatchPath(variant: swatchVariant))
            meadow.name = "\(semanticName).undeveloped-meadow"
            meadow.fillColor = NSColor(
                calibratedRed: 0.28,
                green: 0.43,
                blue: 0.22,
                alpha: identity == .meadow ? 0.20 : 0.10
            )
            meadow.strokeColor = .clear
            meadow.position = CGPoint(x: -1, y: -3)
            meadow.zPosition = -2
            composition.addChild(meadow)

            switch identity {
            case .meadow:
                addWildflowerMeadow(
                    to: composition,
                    coordinate: coordinate,
                    semanticName: semanticName
                )
            case .shrubPatch:
                addLowShrubPatch(
                    to: composition,
                    coordinate: coordinate,
                    semanticName: semanticName
                )
            case .singleGrove, .asymmetricCopse:
                addVacantGrove(
                    identity: identity,
                    to: composition,
                    detail: detail,
                    semanticName: semanticName
                )
            }
            let scale = 0.62 + 0.16 * WorldVisualSeed.unit(
                for: coordinate,
                kind: .empty,
                salt: 0x6A24
            )
            composition.setScale(scale)
            landscape.addChild(composition)
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

    private func vacantLandscapeIdentities(
        for anchors: [GridCoordinate]
    ) -> [GridCoordinate: VacantLandscapeIdentity] {
        let rotation = anchors.first.map {
            WorldVisualSeed.variant(
                count: VacantLandscapeIdentity.allCases.count,
                for: $0,
                kind: .empty,
                salt: 0x6A29
            )
        } ?? 0
        var assigned: [GridCoordinate: VacantLandscapeIdentity] = [:]
        var remaining: [VacantLandscapeIdentity: Int] = [
            .meadow: 3,
            .shrubPatch: 3,
            .singleGrove: 1,
            .asymmetricCopse: 1,
        ]

        func assign(_ index: Int) -> Bool {
            guard index < anchors.count else { return true }
            let coordinate = anchors[index]
            let preferred = (rotation + index) % VacantLandscapeIdentity.allCases.count
            for offset in 0..<VacantLandscapeIdentity.allCases.count {
                let rawValue = (preferred + offset) % VacantLandscapeIdentity.allCases.count
                guard let candidate = VacantLandscapeIdentity(rawValue: rawValue) else { continue }
                guard remaining[candidate, default: 0] > 0 else { continue }
                let repeatsNearby = assigned.contains { entry in
                    let otherCoordinate = entry.key
                    let identity = entry.value
                    let distance = abs(otherCoordinate.x - coordinate.x)
                        + abs(otherCoordinate.y - coordinate.y)
                    return distance <= 3 && identity == candidate
                }
                if !repeatsNearby {
                    assigned[coordinate] = candidate
                    remaining[candidate, default: 0] -= 1
                    if assign(index + 1) { return true }
                    remaining[candidate, default: 0] += 1
                    assigned[coordinate] = nil
                }
            }
            return false
        }
        if !assign(0) {
            // Small or tightly clustered maps still receive deterministic
            // landscape meaning even when the preferred separation cannot be
            // satisfied. The production starter district takes the separated
            // path above; this fallback never invents occupancy.
            assigned.removeAll()
            for (index, coordinate) in anchors.enumerated() {
                assigned[coordinate] = VacantLandscapeIdentity.allCases[
                    (rotation + index) % VacantLandscapeIdentity.allCases.count
                ]
            }
        }
        return assigned
    }

    private func addWildflowerMeadow(
        to root: SKNode,
        coordinate: GridCoordinate,
        semanticName: String
    ) {
        let patch = SKNode()
        patch.name = "\(semanticName).wildflower-meadow"
        let baseSeed = WorldVisualSeed.variant(
            count: 3,
            for: coordinate,
            kind: .empty,
            salt: 0x6A2A
        )
        let positions = [
            CGPoint(x: -11 + CGFloat(baseSeed), y: -1),
            CGPoint(x: -4, y: 3),
            CGPoint(x: 4 + CGFloat(baseSeed), y: -3),
            CGPoint(x: 11, y: 2),
            CGPoint(x: 1, y: 5),
        ]
        for (index, position) in positions.enumerated() {
            let tuft = SKShapeNode(
                ellipseOf: CGSize(
                    width: 5.2 + CGFloat(index % 3),
                    height: 2.4 + CGFloat(index % 2) * 0.7
                )
            )
            tuft.name = "\(semanticName).meadow-tuft.\(index)"
            tuft.fillColor = NSColor(
                calibratedRed: 0.20,
                green: 0.35 + CGFloat(index % 2) * 0.022,
                blue: 0.19,
                alpha: 0.64
            )
            tuft.strokeColor = .clear
            tuft.position = position
            tuft.zRotation = (CGFloat(index % 3) - 1) * 0.14
            patch.addChild(tuft)

            let flower = SKShapeNode(
                ellipseOf: CGSize(
                    width: index.isMultiple(of: 2) ? 1.4 : 1.1,
                    height: index.isMultiple(of: 2) ? 0.9 : 1.3
                )
            )
            flower.name = "\(semanticName).wildflower.\(index)"
            flower.fillColor = index.isMultiple(of: 2)
                ? NSColor(calibratedRed: 0.72, green: 0.58, blue: 0.30, alpha: 0.72)
                : NSColor(calibratedRed: 0.58, green: 0.38, blue: 0.40, alpha: 0.66)
            flower.strokeColor = .clear
            flower.position = CGPoint(x: position.x + 0.7, y: position.y + 1.2)
            patch.addChild(flower)
        }
        root.addChild(patch)
    }

    private func addLowShrubPatch(
        to root: SKNode,
        coordinate: GridCoordinate,
        semanticName: String
    ) {
        let patch = SKNode()
        patch.name = "\(semanticName).low-shrub-patch"
        let contact = SKShapeNode(ellipseOf: CGSize(width: 34, height: 6))
        contact.fillColor = NSColor.black.withAlphaComponent(0.09)
        contact.strokeColor = .clear
        contact.position = CGPoint(x: 1, y: -2.5)
        patch.addChild(contact)
        let offset = WorldVisualSeed.unit(
            for: coordinate,
            kind: .empty,
            salt: 0x6A2B
        ) * 4 - 2
        let xPositions: [CGFloat] = [-10, -3, 5, 11]
        for (index, x) in xPositions.enumerated() {
            let backLobe = SKShapeNode(
                ellipseOf: CGSize(
                    width: 9 + CGFloat(index % 2) * 2,
                    height: 5.4 + CGFloat((index + 1) % 2)
                )
            )
            backLobe.name = "\(semanticName).shrub.\(index).back"
            backLobe.fillColor = NSColor(
                calibratedRed: 0.12 + CGFloat(index) * 0.012,
                green: 0.25 + CGFloat(index) * 0.018,
                blue: 0.14,
                alpha: 0.88
            )
            backLobe.strokeColor = .clear
            backLobe.position = CGPoint(
                x: x + offset,
                y: CGFloat((index * 3) % 4) - 1
            )
            backLobe.zRotation = (CGFloat(index % 3) - 1) * 0.11
            patch.addChild(backLobe)

            let frontLobe = SKShapeNode(
                ellipseOf: CGSize(
                    width: 6.5 + CGFloat((index + 1) % 2),
                    height: 3.8 + CGFloat(index % 2) * 0.6
                )
            )
            frontLobe.name = "\(semanticName).shrub.\(index).front"
            frontLobe.fillColor = NSColor(
                calibratedRed: 0.16 + CGFloat(index) * 0.011,
                green: 0.32 + CGFloat(index) * 0.016,
                blue: 0.17,
                alpha: 0.92
            )
            frontLobe.strokeColor = .clear
            frontLobe.position = CGPoint(
                x: x + offset + 1.8,
                y: CGFloat((index * 3) % 4)
            )
            frontLobe.zRotation = (CGFloat((index + 1) % 3) - 1) * 0.13
            frontLobe.zPosition = 0.2
            patch.addChild(frontLobe)

            if index.isMultiple(of: 2) {
                let seed = SKShapeNode(
                    ellipseOf: CGSize(width: 1.2, height: 0.8)
                )
                seed.name = "\(semanticName).shrub-seed.\(index)"
                seed.fillColor = NSColor(
                    calibratedRed: 0.61,
                    green: 0.50,
                    blue: 0.28,
                    alpha: 0.55
                )
                seed.strokeColor = .clear
                seed.position = CGPoint(
                    x: x + offset + 2.5,
                    y: CGFloat((index * 3) % 4) + 1.2
                )
                seed.zPosition = 0.4
                patch.addChild(seed)
            }
        }
        root.addChild(patch)
    }

    private func addVacantGrove(
        identity: VacantLandscapeIdentity,
        to root: SKNode,
        detail: CameraDetailLevel,
        semanticName: String
    ) {
        guard let primary = assets.generatedSprite(
            logicalID: "ambient_vegetation_cluster",
            detail: detail
        ) else { return }
        primary.name = "\(semanticName).primary.generated-v4.\(detail.assetSuffix)"
        primary.position = identity == .asymmetricCopse
            ? CGPoint(x: -5, y: 1)
            : .zero
        root.addChild(primary)
        if identity == .asymmetricCopse,
           let companion = assets.generatedSprite(
               logicalID: "ambient_vegetation_cluster",
               detail: detail
           ) {
            companion.name = "\(semanticName).companion.generated-v4.\(detail.assetSuffix)"
            companion.position = CGPoint(x: 13, y: -5)
            companion.setScale(0.46)
            companion.zPosition = -0.5
            root.addChild(companion)
        }

        let contact = SKShapeNode(ellipseOf: CGSize(width: 24, height: 6))
        contact.name = "\(semanticName).ground-contact"
        contact.fillColor = NSColor.black.withAlphaComponent(0.08)
        contact.strokeColor = .clear
        contact.position = CGPoint(x: 2, y: -4)
        contact.zPosition = -1
        root.addChild(contact)
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

    private func normalized(_ point: CGPoint) -> CGPoint {
        let length = max(0.001, hypot(point.x, point.y))
        return CGPoint(x: point.x / length, y: point.y / length)
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
