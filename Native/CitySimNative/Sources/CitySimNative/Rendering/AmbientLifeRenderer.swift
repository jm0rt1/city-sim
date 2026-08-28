import SpriteKit

/// Adds bounded, truth-safe ambient vignettes. Pedestrians follow the typed
/// local-activity signal, while road vehicles follow the simulation-derived
/// traffic-pressure signal on connected road coordinates.
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

    struct RoadTrafficPlacement: Equatable, Sendable {
        let coordinate: GridCoordinate
        let intensity: Double
    }

    struct SidewalkSlot: Hashable, Sendable {
        let coordinate: GridCoordinate
        let edge: RoadConnectionMask
        let side: Int

        init(
            coordinate: GridCoordinate,
            edge: RoadConnectionMask,
            side: CGFloat
        ) {
            self.coordinate = coordinate
            self.edge = edge
            self.side = side < 0 ? -1 : 1
        }
    }

    struct ActivityCandidates: Equatable, Sendable {
        let streets: [ActivityCandidate]
        let places: [ActivityCandidate]
        let reservedSurfaces: Set<GridCoordinate>
    }

    struct ActivityCandidate: Equatable, Sendable {
        let domain: ActivityDomain
        let sourceCoordinate: GridCoordinate
        let surfaceCoordinate: GridCoordinate
        let sidewalkSlot: SidewalkSlot
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
    private let groundEcologyAssets: FourViewGroundEcologyCatalog?
    private(set) var lastActivityPlacements: [ActivityPlacement] = []

    init(
        style: WorldVisualStyle,
        assets: WorldAssetCatalog,
        groundEcologyAssets: FourViewGroundEcologyCatalog? = nil
    ) {
        self.style = style
        self.assets = assets
        self.groundEcologyAssets = groundEcologyAssets
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
        reducedMotion: Bool,
        resolvedActivityPlacements: [ActivityPlacement]? = nil,
        resolvedTrafficPlacements: [RoadTrafficPlacement]? = nil
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
        let roads = corridorRoads(
            from: candidateRoads,
            developedCoordinates: developedCoordinates,
            in: state
        )
        guard !roads.isEmpty else { return root }

        let preferredRoadOrder = Array(roads.indices.dropFirst(2)) + Array(roads.indices.prefix(2))
        var furniturePlacementByRoadIndex: [Int: (edge: RoadConnectionMask, side: CGFloat)] = [:]
        var furnitureByRoadIndex: [Int: SKNode] = [:]
        for roadIndex in preferredRoadOrder where furniturePlacementByRoadIndex.count < 3 {
            let road = roads[roadIndex]
            guard let placement = streetFurniturePlacement(
                at: road.coordinate,
                index: furniturePlacementByRoadIndex.count,
                in: state
            ), roadsidePlantingPlacement(
                at: road.coordinate,
                index: roadIndex,
                in: state,
                avoiding: placement
            ) != nil else { continue }
            let furnitureIndex = furniturePlacementByRoadIndex.count
            furniturePlacementByRoadIndex[roadIndex] = placement
            if detail.includes(.neighborhood) {
                furnitureByRoadIndex[roadIndex] = streetFurniture(
                    at: road.coordinate,
                    index: furnitureIndex,
                    position: style.isoPosition(road.coordinate),
                    placement: placement
                )
            }
        }

        var occupiedVegetationCoordinates: Set<GridCoordinate> = []
        for (index, road) in roads.enumerated() {
            let vignette = SKNode()
            vignette.name = "world.ambient.vignette.\(index)"

            if let furniture = furnitureByRoadIndex[index] {
                vignette.addChild(furniture)
            }

            if let planting = roadsidePlanting(
                at: road.coordinate,
                index: index,
                in: state,
                detail: detail,
                position: style.isoPosition(road.coordinate),
                avoiding: furniturePlacementByRoadIndex[index]
            ) {
                vignette.addChild(planting)
            } else if groundEcologyAssets == nil,
                      (index == 0 || index == 4), let coordinate = vegetationCoordinate(
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
        let placements = resolvedActivityPlacements ?? activityPlacements(
            in: state,
            consequences: consequences,
            detail: detail,
            reserving: activityReservedSidewalkSlots(
                in: state,
                detail: detail
            )
        )
        let activity = makeLocalActivity(
            placements: placements,
            detail: detail,
            reducedMotion: reducedMotion
        )
        if !activity.children.isEmpty {
            root.addChild(activity)
        }
        let trafficPlacements = resolvedTrafficPlacements ?? roadTrafficPlacements(
            in: state,
            consequences: consequences,
            detail: detail
        )
        let traffic = makeRoadTraffic(
            placements: trafficPlacements,
            in: state,
            detail: detail,
            reducedMotion: reducedMotion
        )
        if !traffic.children.isEmpty {
            root.addChild(traffic)
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

    /// Returns the exact sidewalk slots occupied by deterministic furniture
    /// and production planting. Reserving slots instead of whole road tiles
    /// keeps accepted public-realm art collision-free without erasing every
    /// pedestrian from an otherwise active corridor.
    func activityReservedSidewalkSlots(
        in state: CityGameState,
        detail: CameraDetailLevel
    ) -> Set<SidewalkSlot> {
        guard groundEcologyAssets != nil else { return [] }
        let completed = state.tiles.filter {
            $0.kind != .empty && $0.kind != .road && $0.constructionProgress >= 1
        }
        let developedCoordinates = completed.map(\.coordinate)
        guard !developedCoordinates.isEmpty else { return [] }
        let candidateRoads = state.tiles.filter { tile in
            guard tile.kind == .road else { return false }
            let distance = developedCoordinates.map {
                abs($0.x - tile.coordinate.x) + abs($0.y - tile.coordinate.y)
            }.min() ?? .max
            return distance <= 4
        }
        let roads = corridorRoads(
            from: candidateRoads,
            developedCoordinates: developedCoordinates,
            in: state
        )
        var reserved: Set<SidewalkSlot> = []
        let preferredRoadOrder = Array(roads.indices.dropFirst(2))
            + Array(roads.indices.prefix(2))
        var furniturePlacementByRoadIndex: [Int: (edge: RoadConnectionMask, side: CGFloat)] = [:]
        var furnitureCount = 0
        for roadIndex in preferredRoadOrder where furnitureCount < 3 {
            let road = roads[roadIndex]
            guard let furniture = streetFurniturePlacement(
                at: road.coordinate,
                index: furnitureCount,
                in: state
            ), roadsidePlantingPlacement(
                at: road.coordinate,
                index: roadIndex,
                in: state,
                avoiding: furniture
            ) != nil else { continue }
            furniturePlacementByRoadIndex[roadIndex] = furniture
            if detail.includes(.neighborhood) {
                reserved.insert(SidewalkSlot(
                    coordinate: road.coordinate,
                    edge: furniture.edge,
                    side: furniture.side
                ))
            }
            furnitureCount += 1
        }
        for (roadIndex, road) in roads.enumerated() {
            guard let planting = roadsidePlantingPlacement(
                at: road.coordinate,
                index: roadIndex,
                in: state,
                avoiding: furniturePlacementByRoadIndex[roadIndex]
            ) else { continue }
            reserved.insert(SidewalkSlot(
                coordinate: road.coordinate,
                edge: planting.edge,
                side: planting.side
            ))
        }
        return reserved
    }

    func activityPlacements(
        in state: CityGameState,
        consequences: CitySpatialConsequenceMap,
        detail: CameraDetailLevel,
        excluding excludedRoads: Set<GridCoordinate> = []
    ) -> [ActivityPlacement] {
        let candidates = activityCandidates(in: state, excluding: excludedRoads)
        return activityPlacements(
            in: state,
            candidates: candidates,
            detail: detail,
            streetActivityIndex: { consequences[$0]?.streetActivityIndex },
            placeActivityIndex: { consequences[$0]?.placeActivityIndex }
        )
    }

    func activityPlacements(
        in state: CityGameState,
        consequences: CitySpatialConsequenceMap,
        detail: CameraDetailLevel,
        reserving reservedSidewalkSlots: Set<SidewalkSlot>
    ) -> [ActivityPlacement] {
        let candidates = activityCandidates(
            in: state,
            reserving: reservedSidewalkSlots
        )
        return activityPlacements(
            in: state,
            candidates: candidates,
            detail: detail,
            streetActivityIndex: { consequences[$0]?.streetActivityIndex },
            placeActivityIndex: { consequences[$0]?.placeActivityIndex }
        )
    }

    func activityCandidates(
        in state: CityGameState,
        excluding excludedRoads: Set<GridCoordinate> = []
    ) -> ActivityCandidates {
        activityCandidates(
            in: state,
            excluding: excludedRoads,
            reserving: []
        )
    }

    func activityCandidates(
        in state: CityGameState,
        reserving reservedSidewalkSlots: Set<SidewalkSlot>
    ) -> ActivityCandidates {
        activityCandidates(
            in: state,
            excluding: [],
            reserving: reservedSidewalkSlots
        )
    }

    private func activityCandidates(
        in state: CityGameState,
        excluding excludedRoads: Set<GridCoordinate>,
        reserving reservedSidewalkSlots: Set<SidewalkSlot>
    ) -> ActivityCandidates {
        var streets: [ActivityCandidate] = []
        var places: [ActivityCandidate] = []
        streets.reserveCapacity(32)
        places.reserveCapacity(16)
        for tile in state.tiles {
            if tile.kind == .road,
               !excludedRoads.contains(tile.coordinate),
               let geometry = sidewalkActivityGeometry(
                   at: tile.coordinate,
                   in: state,
                   salt: 0xAC7100,
                   excluding: reservedSidewalkSlots
               ) {
                streets.append(ActivityCandidate(
                    domain: .street,
                    sourceCoordinate: tile.coordinate,
                    surfaceCoordinate: tile.coordinate,
                    sidewalkSlot: geometry.slot,
                    position: geometry.position,
                    motionVector: geometry.motionVector
                ))
            } else if tile.kind != .empty,
                      tile.kind != .road,
                      tile.constructionProgress >= 1 {
                let frontages = RoadConnectionMask.resolving(at: tile.coordinate, in: state)
                guard let frontage = ResidentialGeneratedAssetIdentity
                    .authoritativeFrontagePriority
                    .first(where: frontages.contains) else { continue }
                let delta = frontage.coordinateDelta
                let roadCoordinate = GridCoordinate(
                    x: tile.coordinate.x + delta.x,
                    y: tile.coordinate.y + delta.y
                )
                guard !excludedRoads.contains(roadCoordinate),
                      state.tile(at: roadCoordinate)?.kind == .road,
                      let geometry = sidewalkActivityGeometry(
                          at: roadCoordinate,
                          in: state,
                          facing: tile.coordinate,
                          salt: 0xAC7200,
                          excluding: reservedSidewalkSlots
                      ) else { continue }
                places.append(ActivityCandidate(
                    domain: .place,
                    sourceCoordinate: tile.coordinate,
                    surfaceCoordinate: roadCoordinate,
                    sidewalkSlot: geometry.slot,
                    position: geometry.position,
                    motionVector: geometry.motionVector
                ))
            }
        }
        return ActivityCandidates(
            streets: streets,
            places: places,
            reservedSurfaces: excludedRoads
        )
    }

    func activityPlacements(
        in state: CityGameState,
        candidates: ActivityCandidates,
        consequences: CitySpatialConsequenceMap,
        detail: CameraDetailLevel
    ) -> [ActivityPlacement] {
        activityPlacements(
            in: state,
            candidates: candidates,
            detail: detail,
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
        let candidates = activityCandidates(in: state, excluding: excludedRoads)
        return activityPlacements(
            in: state,
            candidates: candidates,
            detail: detail,
            streetActivityIndex: streetActivityIndex,
            placeActivityIndex: placeActivityIndex
        )
    }

    private func activityPlacements(
        in state: CityGameState,
        candidates: ActivityCandidates,
        detail: CameraDetailLevel,
        streetActivityIndex: (GridCoordinate) -> Double?,
        placeActivityIndex: (GridCoordinate) -> Double?
    ) -> [ActivityPlacement] {
        let streetLimit = detail == .city ? 1 : 2
        let placeLimit = 1
        var occupiedSurfaces = candidates.reservedSurfaces
        var placements: [ActivityPlacement] = []
        placements.reserveCapacity(streetLimit + placeLimit)

        var selectedStreetCount = 0
        streetSelection: for band in stride(from: 3, through: 1, by: -1) {
            for candidate in candidates.streets {
                guard selectedStreetCount < streetLimit else {
                    break streetSelection
                }
                guard Self.presentationBand(
                    for: streetActivityIndex(candidate.sourceCoordinate)
                ) == UInt8(band) else { continue }
                occupiedSurfaces.insert(candidate.surfaceCoordinate)
                selectedStreetCount += 1
                placements.append(ActivityPlacement(
                    domain: .street,
                    sourceCoordinate: candidate.sourceCoordinate,
                    surfaceCoordinate: candidate.surfaceCoordinate,
                    intensity: Double(band) / 3,
                    position: candidate.position,
                    motionVector: candidate.motionVector
                ))
            }
        }

        var selectedPlaceCount = 0
        placeSelection: for band in stride(from: 3, through: 1, by: -1) {
            for candidate in candidates.places {
                guard selectedPlaceCount < placeLimit else {
                    break placeSelection
                }
                guard Self.presentationBand(
                    for: placeActivityIndex(candidate.sourceCoordinate)
                ) == UInt8(band) else { continue }
                guard !occupiedSurfaces.contains(candidate.surfaceCoordinate) else {
                    continue
                }
                occupiedSurfaces.insert(candidate.surfaceCoordinate)
                selectedPlaceCount += 1
                placements.append(ActivityPlacement(
                    domain: .place,
                    sourceCoordinate: candidate.sourceCoordinate,
                    surfaceCoordinate: candidate.surfaceCoordinate,
                    intensity: Double(band) / 3,
                    position: candidate.position,
                    motionVector: candidate.motionVector
                ))
            }
        }
        return placements
    }

    func makeLocalActivity(
        placements: [ActivityPlacement],
        detail: CameraDetailLevel,
        reducedMotion: Bool
    ) -> SKNode {
        lastActivityPlacements = placements
        let activity = SKNode()
        activity.name = "world.activity.local"
        guard !placements.isEmpty else { return activity }
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
        return activity
    }

    func roadTrafficPlacements(
        in state: CityGameState,
        consequences: CitySpatialConsequenceMap,
        detail: CameraDetailLevel
    ) -> [RoadTrafficPlacement] {
        let limit = detail == .city ? 3 : 2
        let candidates = state.tiles.filter { tile in
            tile.kind == .road
                && RoadConnectionMask.resolving(
                    at: tile.coordinate,
                    in: state
                ).connectionCount >= 2
                && (Self.presentationBand(
                    for: consequences[tile.coordinate]?.trafficPressure
                ) ?? 0) > 0
        }
        var selected: [CityTile] = []
        for band in stride(from: 3, through: 1, by: -1) {
            for candidate in candidates where selected.count < limit {
                guard Self.presentationBand(
                    for: consequences[candidate.coordinate]?.trafficPressure
                ) == UInt8(band) else { continue }
                let separated = selected.allSatisfy {
                    abs($0.coordinate.x - candidate.coordinate.x)
                        + abs($0.coordinate.y - candidate.coordinate.y) >= 3
                }
                guard separated else { continue }
                selected.append(candidate)
            }
        }
        if selected.count < limit {
            for candidate in candidates where selected.count < limit {
                guard !selected.contains(where: {
                    $0.coordinate == candidate.coordinate
                }) else { continue }
                selected.append(candidate)
            }
        }
        return selected.map { tile in
            let band = Self.presentationBand(
                for: consequences[tile.coordinate]?.trafficPressure
            ) ?? 1
            return RoadTrafficPlacement(
                coordinate: tile.coordinate,
                intensity: Double(band) / 3
            )
        }
    }

    func makeRoadTraffic(
        placements: [RoadTrafficPlacement],
        in state: CityGameState,
        detail: CameraDetailLevel,
        reducedMotion: Bool
    ) -> SKNode {
        let traffic = SKNode()
        traffic.name = "world.traffic.local"
        for (index, placement) in placements.enumerated() {
            let connections = RoadConnectionMask.resolving(
                at: placement.coordinate,
                in: state
            )
            guard connections.connectionCount >= 2,
                  let route = vehicleRoute(
                      at: placement.coordinate,
                      connections: connections,
                      index: index
                  ) else { continue }

            let vehicle = makeVehicle(
                coordinate: placement.coordinate,
                intensity: placement.intensity,
                detail: detail,
                routeVector: route.vector,
                index: index
            )
            vehicle.position = CGPoint(
                x: style.isoPosition(placement.coordinate).x + route.start.x,
                y: style.isoPosition(placement.coordinate).y + route.start.y
            )
            vehicle.zPosition = style.depth(for: placement.coordinate) + 54

            if !reducedMotion, detail != .city {
                let phase = Double(WorldVisualSeed.unit(
                    for: placement.coordinate,
                    kind: .road,
                    salt: 0x7AFF10 + UInt64(index)
                )) * 1.2
                let drive = SKAction.sequence([
                    .moveBy(x: route.vector.x, y: route.vector.y, duration: 2.8),
                    .fadeOut(withDuration: 0.12),
                    .moveBy(x: -route.vector.x, y: -route.vector.y, duration: 0),
                    .fadeIn(withDuration: 0.12),
                    .wait(forDuration: 0.45),
                ])
                vehicle.run(
                    .sequence([.wait(forDuration: phase), .repeatForever(drive)]),
                    withKey: "ambient.road-traffic"
                )
            }
            traffic.addChild(vehicle)
        }
        return traffic
    }

    private func vehicleRoute(
        at coordinate: GridCoordinate,
        connections: RoadConnectionMask,
        index: Int
    ) -> (start: CGPoint, vector: CGPoint)? {
        let edges = connections.edges
        guard edges.count >= 2 else { return nil }
        let startIndex = WorldVisualSeed.variant(
            count: edges.count,
            for: coordinate,
            kind: .road,
            salt: 0x7AFF20 + UInt64(index)
        )
        let incoming = edges[startIndex]
        let outgoing = connections.contains(incoming.opposite)
            ? incoming.opposite
            : edges[(startIndex + 1) % edges.count]
        let incomingSocket = style.roadSocket(for: incoming, overreach: -5)
        let outgoingSocket = style.roadSocket(for: outgoing, overreach: -5)
        let vector = CGPoint(
            x: outgoingSocket.x - incomingSocket.x,
            y: outgoingSocket.y - incomingSocket.y
        )
        let length = max(0.001, hypot(vector.x, vector.y))
        let laneOffset = CGFloat(index.isMultiple(of: 2) ? 1 : -1) * 2.7
        let perpendicular = CGPoint(x: -vector.y / length, y: vector.x / length)
        let start = CGPoint(
            x: incomingSocket.x + perpendicular.x * laneOffset,
            y: incomingSocket.y + perpendicular.y * laneOffset
        )
        return (start, vector)
    }

    private func makeVehicle(
        coordinate: GridCoordinate,
        intensity: Double,
        detail: CameraDetailLevel,
        routeVector: CGPoint,
        index: Int
    ) -> SKNode {
        let vehicle = SKNode()
        vehicle.name = "world.traffic.vehicle.\(coordinate.x).\(coordinate.y)"
        vehicle.zRotation = atan2(routeVector.y, routeVector.x)
        vehicle.alpha = 0.82 + CGFloat(intensity) * 0.16
        let scale: CGFloat = switch detail {
        case .city: 0.94
        case .neighborhood: 1.02
        case .block: 1.10
        }
        vehicle.setScale(scale)

        let shadow = SKShapeNode(ellipseOf: CGSize(width: 10.5, height: 4.1))
        shadow.name = "world.traffic.vehicle.shadow"
        shadow.fillColor = style.palette.shadow.withAlphaComponent(0.48)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0.8, y: -1.2)
        shadow.zPosition = -1
        vehicle.addChild(shadow)

        let bodyColors = [
            NSColor(srgbRed: 0.55, green: 0.20, blue: 0.16, alpha: 1),
            NSColor(srgbRed: 0.16, green: 0.39, blue: 0.47, alpha: 1),
            NSColor(srgbRed: 0.73, green: 0.58, blue: 0.30, alpha: 1),
        ]
        let colorIndex = WorldVisualSeed.variant(
            count: bodyColors.count,
            for: coordinate,
            kind: .road,
            salt: 0x7AFF30 + UInt64(index)
        )
        let body = SKShapeNode(rectOf: CGSize(width: 10, height: 4.5), cornerRadius: 1.35)
        body.name = "world.traffic.vehicle.body"
        body.fillColor = bodyColors[colorIndex]
        body.strokeColor = style.palette.mapEarthDark.withAlphaComponent(0.82)
        body.lineWidth = 0.6
        body.zPosition = 0
        vehicle.addChild(body)

        let cabin = SKShapeNode(rectOf: CGSize(width: 5.2, height: 3.4), cornerRadius: 0.8)
        cabin.name = "world.traffic.vehicle.cabin"
        cabin.fillColor = style.palette.glass.withAlphaComponent(0.88)
        cabin.strokeColor = style.palette.roofDark.withAlphaComponent(0.72)
        cabin.lineWidth = 0.45
        cabin.position.x = -0.35
        cabin.zPosition = 1
        vehicle.addChild(cabin)

        for side: CGFloat in [-1, 1] {
            let headlight = SKShapeNode(circleOfRadius: 0.55)
            headlight.name = "world.traffic.vehicle.headlight"
            headlight.fillColor = style.palette.warmWindow
            headlight.strokeColor = .clear
            headlight.position = CGPoint(x: 4.7, y: side * 1.25)
            headlight.zPosition = 2
            vehicle.addChild(headlight)
        }
        return vehicle
    }

    private func sidewalkActivityGeometry(
        at coordinate: GridCoordinate,
        in state: CityGameState,
        facing target: GridCoordinate? = nil,
        salt: UInt64,
        excluding reservedSidewalkSlots: Set<SidewalkSlot> = []
    ) -> (position: CGPoint, motionVector: CGPoint, slot: SidewalkSlot)? {
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
                let slot = SidewalkSlot(
                    coordinate: coordinate,
                    edge: edge,
                    side: side
                )
                guard !reservedSidewalkSlots.contains(slot) else { continue }
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
                    ),
                    slot: slot
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
        position roadPosition: CGPoint,
        placement: (edge: RoadConnectionMask, side: CGFloat)
    ) -> SKNode {
        let variant = index % 3

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

    private func roadsidePlanting(
        at coordinate: GridCoordinate,
        index: Int,
        in state: CityGameState,
        detail: CameraDetailLevel,
        position roadPosition: CGPoint,
        avoiding furniturePlacement: (edge: RoadConnectionMask, side: CGFloat)?
    ) -> SKNode? {
        guard let groundEcologyAssets,
              let placement = roadsidePlantingPlacement(
                  at: coordinate,
                  index: index,
                  in: state,
                  avoiding: furniturePlacement
              ) else { return nil }
        let assetIDs = [
            "maple_street_tree",
            "marigold_planter_cluster",
            "sage_shrub_cluster",
            "maple_street_tree",
            "marigold_planter_cluster",
        ]
        let assetID = assetIDs[index % assetIDs.count]
        guard let sprite = groundEcologyAssets.makeSprite(
            assetID: assetID,
            worldTileWidth: style.tileWidth,
            zPosition: 0
        ) else { return nil }

        let endpoint = style.roadSocket(for: placement.edge)
        let direction = normalized(endpoint)
        let perpendicular = CGPoint(x: -direction.y, y: direction.x)
        let localCenter = CGPoint(
            x: endpoint.x * 0.50 + perpendicular.x * 11.25 * placement.side,
            y: endpoint.y * 0.50 + perpendicular.y * 11.25 * placement.side
        )
        let root = SKNode()
        root.name = "world.public-realm.street-planting.\(assetID).\(coordinate.x).\(coordinate.y)"
        root.position = CGPoint(
            x: roadPosition.x + localCenter.x,
            y: roadPosition.y + localCenter.y
        )
        root.zPosition = style.depth(for: coordinate) + 55
        sprite.name = "\(root.name ?? "world.public-realm.street-planting").four-view.\(detail.assetSuffix)"
        sprite.position = .zero
        sprite.color = .clear
        sprite.colorBlendFactor = 0
        root.addChild(sprite)
        return root
    }

    private func roadsidePlantingPlacement(
        at coordinate: GridCoordinate,
        index: Int,
        in state: CityGameState,
        avoiding furniturePlacement: (edge: RoadConnectionMask, side: CGFloat)?
    ) -> (edge: RoadConnectionMask, side: CGFloat)? {
        let connections = RoadConnectionMask.resolving(at: coordinate, in: state)
        let edges = connections.edges
        guard !edges.isEmpty else { return nil }

        if let furniturePlacement {
            let opposite = (
                edge: furniturePlacement.edge,
                side: -furniturePlacement.side
            )
            if isClearSidewalkPlacement(
                edge: opposite.edge,
                side: opposite.side,
                connections: connections
            ) {
                return opposite
            }
        }

        let edgeRotation = WorldVisualSeed.variant(
            count: edges.count,
            for: coordinate,
            kind: .road,
            salt: 0x57A40 + UInt64(index)
        )
        let orderedEdges = Array(edges[edgeRotation...] + edges[..<edgeRotation])
        let preferredSide: CGFloat = WorldVisualSeed.unit(
            for: coordinate,
            kind: .road,
            salt: 0x57A50 + UInt64(index)
        ) < 0.5 ? -1 : 1
        let candidates = orderedEdges.flatMap { edge in
            [preferredSide, -preferredSide].map { side in (edge: edge, side: side) }
        }
        return candidates.first(where: { candidate in
            guard candidate.edge != furniturePlacement?.edge
                    || candidate.side != furniturePlacement?.side else {
                return false
            }
            return isClearSidewalkPlacement(
                edge: candidate.edge,
                side: candidate.side,
                connections: connections
            )
        })
    }

    private func streetFurniturePlacement(
        at coordinate: GridCoordinate,
        index: Int,
        in state: CityGameState
    ) -> (edge: RoadConnectionMask, side: CGFloat)? {
        let connections = RoadConnectionMask.resolving(at: coordinate, in: state)
        let orderedEdges = connections.edges
        guard !orderedEdges.isEmpty else { return nil }
        let preferredSide: CGFloat = WorldVisualSeed.unit(
            for: coordinate,
            kind: .road,
            salt: 0x57A33
        ) < 0.5 ? -1 : 1
        let orderedSides = [preferredSide, -preferredSide]
        let orderedCandidates = orderedEdges.flatMap { edge in
            orderedSides.map { side in (edge: edge, side: side) }
        }
        return orderedCandidates.first(where: {
            isClearSidewalkPlacement(
                edge: $0.edge,
                side: $0.side,
                connections: connections
            )
        })
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

    private func corridorRoads(
        from candidates: [CityTile],
        developedCoordinates: [GridCoordinate],
        in state: CityGameState
    ) -> [CityTile] {
        let desiredCount = 5
        guard groundEcologyAssets != nil else {
            return corridorAnchors(
                from: candidates,
                developedCoordinates: developedCoordinates,
                limit: desiredCount
            )
        }
        let expanded = corridorAnchors(
            from: candidates,
            developedCoordinates: developedCoordinates,
            limit: min(candidates.count, desiredCount * 2)
        )
        var selected: [CityTile] = []
        for road in expanded where selected.count < desiredCount {
            guard roadsidePlantingPlacement(
                at: road.coordinate,
                index: selected.count,
                in: state,
                avoiding: nil
            ) != nil else { continue }
            selected.append(road)
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
