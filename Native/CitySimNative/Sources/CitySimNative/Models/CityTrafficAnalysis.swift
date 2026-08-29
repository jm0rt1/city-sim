import Foundation

struct CityTrafficImpact: Equatable, Sendable {
    static let localPenaltyThreshold = 0.55
    static let maximumLocalPenalty = 0.12

    let pressure: Double

    init(pressure: Double) {
        self.pressure = min(1, max(0, pressure))
    }

    var delay: Double { pressure * pressure * 0.75 }
    var reliability: Double { min(1, max(0, 1 - pressure * 0.35)) }
    var appliesLocalPenalty: Bool { pressure > Self.localPenaltyThreshold }
    var localPenalty: Double {
        max(0, (pressure - Self.localPenaltyThreshold) / (1 - Self.localPenaltyThreshold))
            * Self.maximumLocalPenalty
    }
}

struct CityTrafficRoadReading: Identifiable, Equatable, Sendable {
    var id: GridCoordinate { coordinate }

    let coordinate: GridCoordinate
    let assignedTrips: Double
    let pressure: Double
    let delay: Double
    let reliability: Double
}

struct CityTrafficPlaceReading: Identifiable, Equatable, Sendable {
    var id: GridCoordinate { coordinate }

    let coordinate: GridCoordinate
    let exposure: Double
    let commute: CityCommuteAccessReading?
}

struct CityCommuteAccessReading: Equatable, Sendable {
    static let healthyAccessThreshold = 0.75

    let reachableJobs: Int
    let requiredWorkers: Int
    let routeLength: Int?
    let routeReliability: Double
    let access: Double
}

struct CityTrafficAnalysis: Equatable, Sendable {
    let width: Int
    let height: Int
    let roadSamples: [CityTrafficRoadReading?]
    let placeSamples: [CityTrafficPlaceReading?]
    let residentWeightedCommuteAccess: Double

    subscript(_ coordinate: GridCoordinate) -> CityTrafficRoadReading? {
        guard let index = index(for: coordinate) else { return nil }
        return roadSamples[index]
    }

    func place(at coordinate: GridCoordinate) -> CityTrafficPlaceReading? {
        guard let index = index(for: coordinate) else { return nil }
        return placeSamples[index]
    }

    static func residentWeightedCommuteAccess(in state: CityGameState) -> Double {
        CityTrafficAnalysis(state: state, materializesSamples: false)
            .residentWeightedCommuteAccess
    }

    init(state: CityGameState) {
        self.init(state: state, materializesSamples: true)
    }

    private init(state: CityGameState, materializesSamples: Bool) {
        width = state.gridWidth
        height = state.gridHeight
        let sampleCount = width * height
        let roadCoordinates = state.tiles
            .filter { $0.kind == .road }
            .map(\.coordinate)
            .sorted(by: Self.rowMajor)
        let roadSet = Set(roadCoordinates)
        let roadComponents = Self.roadComponents(
            coordinates: roadCoordinates,
            roadSet: roadSet
        )
        var loads = Array(repeating: 0.0, count: sampleCount)
        var assignedCommuteRoutes: [GridCoordinate: [GridCoordinate]] = [:]
        let capacities = Self.roadCapacities(
            coordinates: roadCoordinates,
            roadSet: roadSet,
            width: width,
            height: height
        )

        let residences = state.tiles
            .filter {
                $0.kind == .residential
                    && $0.constructionProgress >= 1
            }
            .sorted { Self.rowMajor($0.coordinate, $1.coordinate) }
        let workplaces = state.tiles
            .filter {
                ($0.kind == .commercial || $0.kind == .industrial)
                    && $0.constructionProgress >= 1
            }
            .sorted { Self.rowMajor($0.coordinate, $1.coordinate) }
        let residentialFallbackUtilization = Self.aggregateFallbackUtilization(
            tiles: residences,
            aggregateOccupancy: state.population
        )
        let workplaceFallbackUtilization = Self.aggregateFallbackUtilization(
            tiles: workplaces,
            aggregateOccupancy: state.jobs
        )
        let residenceRoutes = residences.map { residence in
            let frontages = Self.frontageRoads(for: residence.coordinate, roadSet: roadSet)
            return (
                tile: residence,
                frontages: frontages,
                components: Set(frontages.compactMap { roadComponents[$0] }),
                residents: Self.estimatedOccupancy(
                    of: residence,
                    aggregateFallback: residentialFallbackUtilization
                )
            )
        }
        let workplaceRoutes = workplaces.map { workplace in
            let frontages = Self.frontageRoads(for: workplace.coordinate, roadSet: roadSet)
            let utilization = Self.utilization(
                of: workplace,
                aggregateFallback: workplaceFallbackUtilization
            )
            let demand: Double
            switch workplace.kind {
            case .commercial:
                demand = Self.clamp(state.demand.commercial)
            case .industrial:
                demand = Self.clamp(state.demand.industrial)
            default:
                demand = 0
            }
            return (
                tile: workplace,
                frontages: frontages,
                components: Set(frontages.compactMap { roadComponents[$0] }),
                jobs: Self.estimatedOccupancy(
                    of: workplace,
                    aggregateFallback: workplaceFallbackUtilization
                ),
                weight: utilization * (0.65 + demand * 0.35)
            )
        }
        let workplaceFrontages = workplaceRoutes
            .filter { $0.weight > 0 }
            .flatMap(\.frontages)
        let routeWidth = state.gridWidth
        let routeHeight = state.gridHeight
        let workplaceRouteTrees = [false, true].map { preferHigherIndexes in
            Self.workplaceRouteTree(
                sources: workplaceFrontages,
                roadSet: roadSet,
                width: routeWidth,
                height: routeHeight,
                preferHigherIndexes: preferHigherIndexes
            )
        }
        var jobsByComponent: [Int: Int] = [:]
        var activeWeightsByComponent: [Int: [Double]] = [:]
        for workplace in workplaceRoutes {
            for component in workplace.components {
                jobsByComponent[component, default: 0] += workplace.jobs
                if workplace.weight > 0 {
                    activeWeightsByComponent[component, default: []].append(workplace.weight)
                }
            }
        }
        for component in activeWeightsByComponent.keys {
            activeWeightsByComponent[component]?.sort(by: >)
            activeWeightsByComponent[component] = Array(
                activeWeightsByComponent[component, default: []].prefix(3)
            )
        }
        var workplaceSummaries: [GridCoordinate: WorkplaceSummary] = [:]
        for residence in residenceRoutes {
            let components = residence.components
            if components.count == 1, let component = components.first {
                workplaceSummaries[residence.tile.coordinate] = WorkplaceSummary(
                    reachableJobs: jobsByComponent[component, default: 0],
                    activeWeights: activeWeightsByComponent[component, default: []]
                )
            } else {
                let reachable = workplaceRoutes.filter {
                    !$0.components.isDisjoint(with: components)
                }
                workplaceSummaries[residence.tile.coordinate] = WorkplaceSummary(
                    reachableJobs: reachable.reduce(0) { $0 + $1.jobs },
                    activeWeights: Array(
                        reachable.map(\.weight).filter { $0 > 0 }.sorted(by: >).prefix(3)
                    )
                )
            }
        }

        if !roadCoordinates.isEmpty, !residences.isEmpty, !workplaces.isEmpty {
            for residence in residenceRoutes {
                let origins = residence.frontages
                guard !origins.isEmpty else { continue }
                let summary = workplaceSummaries[residence.tile.coordinate]
                    ?? WorkplaceSummary(reachableJobs: 0, activeWeights: [])
                guard !summary.activeWeights.isEmpty else { continue }
                var candidateRoutes: [[GridCoordinate]] = []
                for (index, tree) in workplaceRouteTrees.enumerated() {
                    guard let route = Self.route(
                        from: origins,
                        using: tree,
                        width: routeWidth,
                        height: routeHeight,
                        preferHigherIndexes: index == 1
                    ), !candidateRoutes.contains(route) else { continue }
                    candidateRoutes.append(route)
                }
                guard let primaryRoute = candidateRoutes.first else { continue }
                let averageDestinationWeight = summary.activeWeights.reduce(0, +)
                    / Double(summary.activeWeights.count)
                let sourceDemand = Self.utilization(
                    of: residence.tile,
                    aggregateFallback: residentialFallbackUtilization
                )
                    * Self.clamp(averageDestinationWeight)
                assignedCommuteRoutes[residence.tile.coordinate] = primaryRoute
                var remainingDemand = sourceDemand
                while remainingDemand > 0.000_001 {
                    let quantum = min(0.50, remainingDemand)
                    let route = candidateRoutes.enumerated().min { lhs, rhs in
                        let leftScore = Self.routeLoadScore(
                            lhs.element,
                            loads: loads,
                            capacities: capacities,
                            width: routeWidth
                        )
                        let rightScore = Self.routeLoadScore(
                            rhs.element,
                            loads: loads,
                            capacities: capacities,
                            width: routeWidth
                        )
                        if abs(leftScore - rightScore) > 0.000_001 {
                            return leftScore < rightScore
                        }
                        return lhs.offset < rhs.offset
                    }?.element ?? primaryRoute
                    for coordinate in route {
                        loads[coordinate.y * routeWidth + coordinate.x] += quantum
                    }
                    remainingDemand -= quantum
                }
            }
        }

        var resolvedRoads = materializesSamples
            ? Array<CityTrafficRoadReading?>(repeating: nil, count: sampleCount)
            : []
        if materializesSamples {
            for coordinate in roadCoordinates {
                let index = coordinate.y * width + coordinate.x
                let load = loads[index]
                let capacity = max(0.1, capacities[index])
                let pressure = Self.clamp(load / capacity)
                let impact = CityTrafficImpact(pressure: pressure)
                resolvedRoads[index] = CityTrafficRoadReading(
                    coordinate: coordinate,
                    assignedTrips: load,
                    pressure: pressure,
                    delay: impact.delay,
                    reliability: impact.reliability
                )
            }
        }
        roadSamples = resolvedRoads

        var commuteReadings: [GridCoordinate: CityCommuteAccessReading] = [:]
        var weightedCommuteAccess = 0.0
        var residentWeight = 0.0
        let commuteSampleWidth = state.gridWidth
        for residence in residenceRoutes {
            let residents = residence.residents
            let requiredWorkers = Int((Double(residents) * 0.70).rounded(.up))
            let reachableJobs = workplaceSummaries[residence.tile.coordinate]?.reachableJobs ?? 0

            let route = assignedCommuteRoutes[residence.tile.coordinate]
            let routeLength = route.map { max(0, $0.count - 1) }
            let routeReliability = route?.map { coordinate in
                let index = coordinate.y * commuteSampleWidth + coordinate.x
                let pressure = Self.clamp(loads[index] / max(0.1, capacities[index]))
                return CityTrafficImpact(pressure: pressure).reliability
            }.min() ?? 0
            let jobCoverage = requiredWorkers == 0
                ? 1
                : Self.clamp(Double(reachableJobs) / Double(requiredWorkers))
            let distanceQuality: Double
            if let routeLength {
                let excess = max(0, routeLength - 8)
                distanceQuality = Self.clamp(1 - Double(excess) / 24)
            } else {
                distanceQuality = 0
            }
            let access = route == nil ? 0 : Self.clamp(
                jobCoverage * 0.55
                    + routeReliability * 0.30
                    + distanceQuality * 0.15
            )
            if materializesSamples {
                commuteReadings[residence.tile.coordinate] = CityCommuteAccessReading(
                    reachableJobs: reachableJobs,
                    requiredWorkers: requiredWorkers,
                    routeLength: routeLength,
                    routeReliability: routeReliability,
                    access: access
                )
            }
            if residents > 0 {
                weightedCommuteAccess += access * Double(residents)
                residentWeight += Double(residents)
            }
        }
        residentWeightedCommuteAccess = residentWeight > 0
            ? Self.clamp(weightedCommuteAccess / residentWeight)
            : 1

        if materializesSamples {
            var resolvedPlaces = Array<CityTrafficPlaceReading?>(repeating: nil, count: sampleCount)
            for tile in state.tiles where Self.isCompletedPlace(tile) {
                let frontages = Self.frontageRoads(for: tile.coordinate, roadSet: roadSet)
                let exposure: Double
                if frontages.isEmpty {
                    exposure = 0
                } else {
                    var peakPressure = 0.0
                    for coordinate in frontages {
                        let index = coordinate.y * state.gridWidth + coordinate.x
                        peakPressure = max(peakPressure, resolvedRoads[index]?.pressure ?? 0)
                    }
                    exposure = peakPressure
                }
                resolvedPlaces[tile.coordinate.y * width + tile.coordinate.x] = CityTrafficPlaceReading(
                    coordinate: tile.coordinate,
                    exposure: exposure,
                    commute: commuteReadings[tile.coordinate]
                )
            }
            placeSamples = resolvedPlaces
        } else {
            placeSamples = []
        }
    }

    private struct WorkplaceSummary {
        let reachableJobs: Int
        let activeWeights: [Double]
    }

    private struct WorkplaceRouteTree {
        let distances: [Int]
        let nextRoadIndexes: [Int?]
    }

    private func index(for coordinate: GridCoordinate) -> Int? {
        guard coordinate.x >= 0, coordinate.y >= 0,
              coordinate.x < width, coordinate.y < height else { return nil }
        return coordinate.y * width + coordinate.x
    }

    private static func roadCapacities(
        coordinates: [GridCoordinate],
        roadSet: Set<GridCoordinate>,
        width: Int,
        height: Int
    ) -> [Double] {
        var capacities = Array(repeating: 0.0, count: width * height)
        for coordinate in coordinates {
            let connections = orthogonalNeighbors(of: coordinate).filter(roadSet.contains).count
            capacities[coordinate.y * width + coordinate.x] = 0.85
                + Double(max(0, connections - 1)) * 0.10
        }
        return capacities
    }

    private static func roadComponents(
        coordinates: [GridCoordinate],
        roadSet: Set<GridCoordinate>
    ) -> [GridCoordinate: Int] {
        var components: [GridCoordinate: Int] = [:]
        var nextComponent = 0
        for coordinate in coordinates where components[coordinate] == nil {
            var queue = [coordinate]
            components[coordinate] = nextComponent
            var cursor = 0
            while cursor < queue.count {
                let current = queue[cursor]
                cursor += 1
                for neighbor in orthogonalNeighbors(of: current).sorted(by: rowMajor)
                where roadSet.contains(neighbor) && components[neighbor] == nil {
                    components[neighbor] = nextComponent
                    queue.append(neighbor)
                }
            }
            nextComponent += 1
        }
        return components
    }

    private static func workplaceRouteTree(
        sources: [GridCoordinate],
        roadSet: Set<GridCoordinate>,
        width: Int,
        height: Int,
        preferHigherIndexes: Bool
    ) -> WorkplaceRouteTree {
        let sampleCount = width * height
        var distances = Array(repeating: Int.max, count: sampleCount)
        var nextRoadIndexes = Array<Int?>(repeating: nil, count: sampleCount)
        let orderedSources = Array(Set(sources)).sorted {
            preferHigherIndexes ? rowMajor($1, $0) : rowMajor($0, $1)
        }
        var queue = orderedSources
        for source in orderedSources {
            let index = source.y * width + source.x
            distances[index] = 0
        }

        var cursor = 0
        while cursor < queue.count {
            let coordinate = queue[cursor]
            cursor += 1
            let index = coordinate.y * width + coordinate.x
            let candidateDistance = distances[index] + 1
            for neighbor in orthogonalNeighbors(of: coordinate).sorted(by: {
                preferHigherIndexes ? rowMajor($1, $0) : rowMajor($0, $1)
            })
            where neighbor.x >= 0 && neighbor.y >= 0
                && neighbor.x < width && neighbor.y < height
                && roadSet.contains(neighbor) {
                let neighborIndex = neighbor.y * width + neighbor.x
                if candidateDistance < distances[neighborIndex] {
                    distances[neighborIndex] = candidateDistance
                    nextRoadIndexes[neighborIndex] = index
                    queue.append(neighbor)
                } else if candidateDistance == distances[neighborIndex] {
                    let existing = nextRoadIndexes[neighborIndex]
                        ?? (preferHigherIndexes ? Int.min : Int.max)
                    if preferHigherIndexes ? index > existing : index < existing {
                        nextRoadIndexes[neighborIndex] = index
                    }
                }
            }
        }
        return WorkplaceRouteTree(
            distances: distances,
            nextRoadIndexes: nextRoadIndexes
        )
    }

    private static func route(
        from origins: [GridCoordinate],
        using tree: WorkplaceRouteTree,
        width: Int,
        height: Int,
        preferHigherIndexes: Bool
    ) -> [GridCoordinate]? {
        let originIndex = origins
            .map { $0.y * width + $0.x }
            .filter { tree.distances[$0] != Int.max }
            .min { lhs, rhs in
                if tree.distances[lhs] != tree.distances[rhs] {
                    return tree.distances[lhs] < tree.distances[rhs]
                }
                return preferHigherIndexes ? lhs > rhs : lhs < rhs
            }
        guard var current = originIndex else { return nil }
        var route: [GridCoordinate] = []
        route.reserveCapacity(tree.distances[current] + 1)
        for _ in 0..<(width * height) {
            route.append(GridCoordinate(x: current % width, y: current / width))
            guard let next = tree.nextRoadIndexes[current] else { return route }
            current = next
        }
        return nil
    }

    private static func routeLoadScore(
        _ route: [GridCoordinate],
        loads: [Double],
        capacities: [Double],
        width: Int
    ) -> Double {
        var peak = 0.0
        var total = 0.0
        for coordinate in route {
            let index = coordinate.y * width + coordinate.x
            let utilization = loads[index] / max(0.1, capacities[index])
            peak = max(peak, utilization)
            total += utilization
        }
        return peak + total * 0.001
    }

    private static func frontageRoads(
        for coordinate: GridCoordinate,
        roadSet: Set<GridCoordinate>
    ) -> [GridCoordinate] {
        orthogonalNeighbors(of: coordinate)
            .filter(roadSet.contains)
            .sorted(by: rowMajor)
    }

    private static func orthogonalNeighbors(of coordinate: GridCoordinate) -> [GridCoordinate] {
        [
            GridCoordinate(x: coordinate.x, y: coordinate.y - 1),
            GridCoordinate(x: coordinate.x + 1, y: coordinate.y),
            GridCoordinate(x: coordinate.x, y: coordinate.y + 1),
            GridCoordinate(x: coordinate.x - 1, y: coordinate.y)
        ]
    }

    private static func utilization(
        of tile: CityTile,
        aggregateFallback: Double?
    ) -> Double {
        if tile.occupancy <= 0 {
            return aggregateFallback ?? 0
        }
        return clamp(Double(tile.occupancy) / Double(max(1, capacity(of: tile))))
    }

    private static func aggregateFallbackUtilization(
        tiles: [CityTile],
        aggregateOccupancy: Int
    ) -> Double? {
        guard aggregateOccupancy > 0,
              tiles.allSatisfy({ $0.occupancy <= 0 }) else { return nil }
        let totalCapacity = tiles.reduce(0) { $0 + capacity(of: $1) }
        guard totalCapacity > 0 else { return nil }
        return clamp(Double(aggregateOccupancy) / Double(totalCapacity))
    }

    private static func estimatedOccupancy(
        of tile: CityTile,
        aggregateFallback: Double?
    ) -> Int {
        if tile.occupancy > 0 {
            return min(capacity(of: tile), tile.occupancy)
        }
        guard let aggregateFallback else { return 0 }
        return Int((Double(capacity(of: tile)) * aggregateFallback).rounded())
    }

    private static func capacity(of tile: CityTile) -> Int {
        switch tile.kind {
        case .residential:
            280 * max(1, tile.level)
        case .commercial, .industrial:
            CitySimulation.jobCapacity(for: tile.kind) * max(1, tile.level)
        default:
            0
        }
    }

    private static func isCompletedPlace(_ tile: CityTile) -> Bool {
        tile.kind != .empty && tile.kind != .road && tile.constructionProgress >= 1
    }

    private static func manhattan(_ lhs: GridCoordinate, _ rhs: GridCoordinate) -> Int {
        abs(lhs.x - rhs.x) + abs(lhs.y - rhs.y)
    }

    private static func rowMajor(_ lhs: GridCoordinate, _ rhs: GridCoordinate) -> Bool {
        if lhs.y != rhs.y { return lhs.y < rhs.y }
        return lhs.x < rhs.x
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
