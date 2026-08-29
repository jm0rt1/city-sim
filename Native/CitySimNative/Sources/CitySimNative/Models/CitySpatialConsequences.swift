import Foundation

enum CityConsequenceBand: Int, CaseIterable, Equatable, Sendable {
    case severe
    case strained
    case healthy
}

enum CityLocationVitality: Int, CaseIterable, Equatable, Sendable {
    case notApplicable
    case strained
    case stable
    case prosperous

    var comparisonBand: CityConsequenceBand? {
        switch self {
        case .notApplicable:
            nil
        case .strained:
            .severe
        case .stable:
            .strained
        case .prosperous:
            .healthy
        }
    }
}

struct CityLocationUtilityService: Equatable, Sendable {
    let power: Double
    let water: Double
    let combined: Double
    let powerBand: CityConsequenceBand
    let waterBand: CityConsequenceBand
    let combinedBand: CityConsequenceBand
}

struct CitySpatialConsequence: Identifiable, Equatable, Sendable {
    var id: GridCoordinate { coordinate }

    let coordinate: GridCoordinate
    let utility: CityLocationUtilityService
    let pollutionExposure: Double
    let pollutionBand: CityConsequenceBand
    let vitalityScore: Double
    let vitality: CityLocationVitality
    let landValueIndex: Double?
    let localHappinessIndex: Double?
    let trafficPressure: Double?
    let trafficExposure: Double?
    let civicService: CityLocationCivicService?
    let streetActivityIndex: Double?
    let placeActivityIndex: Double?

    init(
        coordinate: GridCoordinate,
        utility: CityLocationUtilityService,
        pollutionExposure: Double,
        pollutionBand: CityConsequenceBand,
        vitalityScore: Double,
        vitality: CityLocationVitality,
        landValueIndex: Double? = nil,
        localHappinessIndex: Double? = nil,
        trafficPressure: Double? = nil,
        trafficExposure: Double? = nil,
        civicService: CityLocationCivicService? = nil,
        streetActivityIndex: Double? = nil,
        placeActivityIndex: Double? = nil
    ) {
        self.coordinate = coordinate
        self.utility = utility
        self.pollutionExposure = pollutionExposure
        self.pollutionBand = pollutionBand
        self.vitalityScore = vitalityScore
        self.vitality = vitality
        self.landValueIndex = landValueIndex
        self.localHappinessIndex = localHappinessIndex
        self.trafficPressure = trafficPressure
        self.trafficExposure = trafficExposure
        self.civicService = civicService
        self.streetActivityIndex = streetActivityIndex
        self.placeActivityIndex = placeActivityIndex
    }
}

struct CitySpatialConsequenceMap: Equatable, Sendable {
    let width: Int
    let height: Int
    let samples: [CitySpatialConsequence]
    let commuteRoutes: [CityCommuteRouteReading]

    subscript(_ coordinate: GridCoordinate) -> CitySpatialConsequence? {
        guard coordinate.x >= 0, coordinate.y >= 0,
              coordinate.x < width, coordinate.y < height else { return nil }
        let index = coordinate.y * width + coordinate.x
        guard samples.indices.contains(index), samples[index].coordinate == coordinate else { return nil }
        return samples[index]
    }

    init(state: CityGameState) {
        let gridWidth = state.gridWidth
        let gridHeight = state.gridHeight
        width = gridWidth
        height = gridHeight

        let activeTiles = CitySimulation.activeTiles(in: state)
        let powerSources = activeTiles.filter { $0.kind == .powerPlant }.map(\.coordinate)
        let waterSources = activeTiles.filter { $0.kind == .waterTower }.map(\.coordinate)
        let industrialSources = activeTiles.filter { $0.kind == .industrial }.map(\.coordinate)
        let parkSources = activeTiles.filter { $0.kind == .park }.map(\.coordinate)
        let powerDistances = DistanceField(width: gridWidth, height: gridHeight, sources: powerSources)
        let waterDistances = DistanceField(width: gridWidth, height: gridHeight, sources: waterSources)
        let industrialDistances = DistanceField(width: gridWidth, height: gridHeight, sources: industrialSources)
        let parkDistances = DistanceField(width: gridWidth, height: gridHeight, sources: parkSources)
        let traffic = CityTrafficAnalysis(state: state)
        commuteRoutes = traffic.commuteRoutes
        let civicServices = CityCivicServiceAnalysis(state: state)
        let powerCapacityFactor = Self.capacityFactor(capacity: state.powerCapacity, used: state.powerUsed)
        let waterCapacityFactor = Self.capacityFactor(capacity: state.waterCapacity, used: state.waterUsed)

        let orderedTiles = state.tiles.sorted(by: Self.rowMajor)
        let baseSamples = orderedTiles.map { tile in
            let power = Self.utilityService(
                at: tile.coordinate,
                distances: powerDistances,
                capacityFactor: powerCapacityFactor
            )
            let water = Self.utilityService(
                at: tile.coordinate,
                distances: waterDistances,
                capacityFactor: waterCapacityFactor
            )
            let combined = min(power, water)
            let utility = CityLocationUtilityService(
                power: power,
                water: water,
                combined: combined,
                powerBand: Self.serviceBand(power),
                waterBand: Self.serviceBand(water),
                combinedBand: Self.serviceBand(combined)
            )

            let industrialInfluence = Self.proximityInfluence(
                from: tile.coordinate,
                distances: industrialDistances,
                radius: 6
            ) * 0.62
            let powerInfluence = Self.proximityInfluence(
                from: tile.coordinate,
                distances: powerDistances,
                radius: 8
            ) * 0.82
            let parkRelief = Self.proximityInfluence(
                from: tile.coordinate,
                distances: parkDistances,
                radius: 3
            ) * 0.16
            let pollutionExposure = Self.clamp(industrialInfluence + powerInfluence - parkRelief)

            let vitalityScore: Double
            let vitality: CityLocationVitality
            let trafficPlace = traffic.place(at: tile.coordinate)
            let trafficExposure = trafficPlace?.exposure
            let commuteAccess = trafficPlace?.commute?.access
            let trafficPenalty = CityTrafficImpact(
                pressure: trafficExposure ?? 0
            ).localPenalty
            let commutePenalty = (1 - (commuteAccess ?? 1)) * 0.24
            let civicService = civicServices[tile.coordinate]
            let isCompletedDevelopment = tile.kind != .empty
                && tile.kind != .road
                && tile.constructionProgress >= 1
            if !isCompletedDevelopment {
                vitalityScore = 0
                vitality = .notApplicable
            } else {
                let utilization = Self.utilization(of: tile)
                vitalityScore = Self.clamp(
                    Self.clamp(tile.condition) * 0.30
                        + utilization * 0.25
                        + combined * 0.20
                        + (1 - pollutionExposure) * 0.15
                        + Self.clamp(state.happiness / 100) * 0.10
                        + (civicService?.combined ?? 0) * 0.10
                        - trafficPenalty * 0.50
                        - commutePenalty
                )
                switch vitalityScore {
                case ..<0.45:
                    vitality = .strained
                case ..<0.72:
                    vitality = .stable
                default:
                    vitality = .prosperous
                }
            }

            let parkProximity = Self.proximityInfluence(
                from: tile.coordinate,
                distances: parkDistances,
                radius: 3
            )
            let landValueIndex: Double?
            let localHappinessIndex: Double?
            if isCompletedDevelopment {
                let roadAccess = state.neighbors(of: tile.coordinate).contains {
                    $0.kind == .road
                } ? 1.0 : 0.0
                let condition = Self.clamp(tile.condition)
                let pollutionSafety = 1 - pollutionExposure
                landValueIndex = Self.clamp(
                    roadAccess * 0.20
                        + combined * 0.25
                        + condition * 0.25
                        + pollutionSafety * 0.20
                        + parkProximity * 0.10
                        + (civicService?.combined ?? 0) * 0.10
                        - trafficPenalty
                        - commutePenalty
                )
                localHappinessIndex = Self.clamp(
                    Self.clamp(state.happiness / 100) * 0.40
                        + combined * 0.20
                        + condition * 0.15
                        + pollutionSafety * 0.15
                        + parkProximity * 0.10
                        + (civicService?.combined ?? 0) * 0.10
                        - trafficPenalty * 0.80
                        - commutePenalty
                )
            } else {
                landValueIndex = nil
                localHappinessIndex = nil
            }

            return CitySpatialConsequence(
                coordinate: tile.coordinate,
                utility: utility,
                pollutionExposure: pollutionExposure,
                pollutionBand: Self.pollutionBand(pollutionExposure),
                vitalityScore: vitalityScore,
                vitality: vitality,
                landValueIndex: landValueIndex,
                localHappinessIndex: localHappinessIndex,
                trafficPressure: traffic[tile.coordinate]?.pressure,
                trafficExposure: isCompletedDevelopment ? trafficExposure : nil,
                civicService: isCompletedDevelopment ? civicService : nil
            )
        }
        samples = zip(orderedTiles, baseSamples).map { tile, sample in
            CitySpatialConsequence(
                coordinate: sample.coordinate,
                utility: sample.utility,
                pollutionExposure: sample.pollutionExposure,
                pollutionBand: sample.pollutionBand,
                vitalityScore: sample.vitalityScore,
                vitality: sample.vitality,
                landValueIndex: sample.landValueIndex,
                localHappinessIndex: sample.localHappinessIndex,
                trafficPressure: sample.trafficPressure,
                trafficExposure: sample.trafficExposure,
                civicService: sample.civicService,
                streetActivityIndex: tile.kind == .road
                    ? Self.streetActivityIndex(
                        at: tile.coordinate,
                        in: state,
                        samples: baseSamples,
                        width: gridWidth,
                        height: gridHeight
                    )
                    : nil,
                placeActivityIndex: Self.isCompletedPlace(tile)
                    ? Self.placeActivityIndex(tile: tile, consequence: sample, in: state)
                    : nil
            )
        }
    }

    private static func rowMajor(_ lhs: CityTile, _ rhs: CityTile) -> Bool {
        if lhs.coordinate.y == rhs.coordinate.y {
            return lhs.coordinate.x < rhs.coordinate.x
        }
        return lhs.coordinate.y < rhs.coordinate.y
    }

    private static func capacityFactor(capacity: Int, used: Int) -> Double {
        clamp(Double(capacity) / Double(max(1, used)))
    }

    private static func utilityService(
        at coordinate: GridCoordinate,
        distances: DistanceField,
        capacityFactor: Double
    ) -> Double {
        guard let distance = distances[coordinate] else { return 0 }
        let reach = max(0, 1 - Double(distance) / 12)
        return min(reach, capacityFactor)
    }

    private static func serviceBand(_ service: Double) -> CityConsequenceBand {
        switch service {
        case ..<0.50: .severe
        case ..<0.85: .strained
        default: .healthy
        }
    }

    private static func pollutionBand(_ exposure: Double) -> CityConsequenceBand {
        switch exposure {
        case ..<0.25: .healthy
        case ..<0.55: .strained
        default: .severe
        }
    }

    private static func utilization(of tile: CityTile) -> Double {
        let capacity: Int
        switch tile.kind {
        case .residential:
            capacity = 280 * max(1, tile.level)
        case .commercial, .industrial:
            capacity = CitySimulation.jobCapacity(for: tile.kind) * max(1, tile.level)
        default:
            return 1
        }
        return clamp(Double(tile.occupancy) / Double(max(1, capacity)))
    }

    private static func isCompletedPlace(_ tile: CityTile) -> Bool {
        tile.kind != .empty
            && tile.kind != .road
            && tile.constructionProgress >= 1
    }

    private static func placeActivityPotential(of tile: CityTile) -> Double {
        switch tile.kind {
        case .residential, .commercial, .industrial:
            utilization(of: tile)
        case .park, .powerPlant, .waterTower, .fireStation, .policeStation,
             .school, .cityHall:
            1
        case .empty, .road:
            0
        }
    }

    private static func placeActivityIndex(
        tile: CityTile,
        consequence: CitySpatialConsequence,
        in state: CityGameState
    ) -> Double {
        let roadAccess = state.neighbors(of: tile.coordinate).contains {
            $0.kind == .road
        } ? 1.0 : 0.0
        return clamp(
            roadAccess * 0.15
                + placeActivityPotential(of: tile) * 0.25
                + clamp(tile.condition) * 0.20
                + consequence.utility.combined * 0.15
                + (consequence.localHappinessIndex ?? 0) * 0.15
                + (1 - consequence.pollutionExposure) * 0.10
        )
    }

    private static func streetActivityIndex(
        at coordinate: GridCoordinate,
        in state: CityGameState,
        samples: [CitySpatialConsequence],
        width: Int,
        height: Int
    ) -> Double {
        let roadConnections = state.neighbors(of: coordinate).filter {
            $0.kind == .road
        }.count
        let connection = Double(roadConnections) / 4
        let traffic = sample(
            at: coordinate,
            in: samples,
            width: width,
            height: height
        )?.trafficPressure ?? 0

        var nearbyVitality = 0.0
        for yOffset in -3...3 {
            for xOffset in -3...3 {
                let distance = abs(xOffset) + abs(yOffset)
                guard distance > 0, distance <= 3,
                      let nearby = sample(
                          at: GridCoordinate(
                              x: coordinate.x + xOffset,
                              y: coordinate.y + yOffset
                          ),
                          in: samples,
                          width: width,
                          height: height
                      ),
                      nearby.vitality != .notApplicable else {
                    continue
                }
                let distanceWeight = 1 - Double(distance) / 4
                nearbyVitality += nearby.vitalityScore * distanceWeight
            }
        }

        return clamp(
            connection * 0.25
                + traffic * 0.45
                + clamp(nearbyVitality / 4) * 0.30
        )
    }

    private static func sample(
        at coordinate: GridCoordinate,
        in samples: [CitySpatialConsequence],
        width: Int,
        height: Int
    ) -> CitySpatialConsequence? {
        guard coordinate.x >= 0, coordinate.y >= 0,
              coordinate.x < width, coordinate.y < height else {
            return nil
        }
        return samples[coordinate.y * width + coordinate.x]
    }

    private static func proximityInfluence(
        from coordinate: GridCoordinate,
        distances: DistanceField,
        radius: Int
    ) -> Double {
        guard let distance = distances[coordinate], distance <= radius else {
            return 0
        }
        return 1 - Double(distance) / Double(max(1, radius))
    }

    private struct DistanceField {
        let width: Int
        let height: Int
        let values: [Int]

        init(width: Int, height: Int, sources: [GridCoordinate]) {
            self.width = width
            self.height = height
            let count = max(0, width * height)
            var values = Array(repeating: Int.max, count: count)
            var queue: [Int] = []
            queue.reserveCapacity(count)

            for source in sources.sorted(by: Self.rowMajor) {
                guard source.x >= 0, source.y >= 0, source.x < width, source.y < height else { continue }
                let index = source.y * width + source.x
                guard values[index] != 0 else { continue }
                values[index] = 0
                queue.append(index)
            }

            var cursor = 0
            while cursor < queue.count {
                let index = queue[cursor]
                cursor += 1
                let x = index % width
                let y = index / width
                let nextDistance = values[index] + 1
                for neighbor in [
                    (x, y - 1),
                    (x + 1, y),
                    (x, y + 1),
                    (x - 1, y)
                ] where neighbor.0 >= 0 && neighbor.1 >= 0
                    && neighbor.0 < width && neighbor.1 < height {
                    let neighborIndex = neighbor.1 * width + neighbor.0
                    guard nextDistance < values[neighborIndex] else { continue }
                    values[neighborIndex] = nextDistance
                    queue.append(neighborIndex)
                }
            }
            self.values = values
        }

        subscript(_ coordinate: GridCoordinate) -> Int? {
            guard coordinate.x >= 0, coordinate.y >= 0,
                  coordinate.x < width, coordinate.y < height else { return nil }
            let value = values[coordinate.y * width + coordinate.x]
            return value == Int.max ? nil : value
        }

        private static func rowMajor(_ lhs: GridCoordinate, _ rhs: GridCoordinate) -> Bool {
            if lhs.y == rhs.y { return lhs.x < rhs.x }
            return lhs.y < rhs.y
        }
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

enum CitySpatialConsequenceDimension: String, CaseIterable, Equatable, Sendable {
    case utility
    case pollution
    case vitality
}

enum CitySpatialConsequenceDirection: String, Equatable, Sendable {
    case worsening
    case recovery
}

struct CitySpatialConsequenceEvent: Identifiable, Equatable, Sendable {
    let id: String
    let authoritativeTick: Int
    let coordinate: GridCoordinate
    let dimension: CitySpatialConsequenceDimension
    let direction: CitySpatialConsequenceDirection
    let fromBand: CityConsequenceBand
    let toBand: CityConsequenceBand
}
