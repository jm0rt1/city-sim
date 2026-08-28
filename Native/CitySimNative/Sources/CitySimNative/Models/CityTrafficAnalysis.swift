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
}

struct CityTrafficAnalysis: Equatable, Sendable {
    let width: Int
    let height: Int
    let roadSamples: [CityTrafficRoadReading?]
    let placeSamples: [CityTrafficPlaceReading?]

    subscript(_ coordinate: GridCoordinate) -> CityTrafficRoadReading? {
        guard let index = index(for: coordinate) else { return nil }
        return roadSamples[index]
    }

    func place(at coordinate: GridCoordinate) -> CityTrafficPlaceReading? {
        guard let index = index(for: coordinate) else { return nil }
        return placeSamples[index]
    }

    init(state: CityGameState) {
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

        if !roadCoordinates.isEmpty, !residences.isEmpty, !workplaces.isEmpty {
            for residence in residences {
                let origins = Self.frontageRoads(for: residence.coordinate, roadSet: roadSet)
                guard !origins.isEmpty else { continue }
                let originComponents = Set(origins.compactMap { roadComponents[$0] })

                let destinations = workplaces
                    .sorted { lhs, rhs in
                        let leftDistance = Self.manhattan(residence.coordinate, lhs.coordinate)
                        let rightDistance = Self.manhattan(residence.coordinate, rhs.coordinate)
                        if leftDistance != rightDistance { return leftDistance < rightDistance }
                        return Self.rowMajor(lhs.coordinate, rhs.coordinate)
                    }
                var weightedDestinations: [WeightedDestination] = []
                for workplace in destinations {
                    if weightedDestinations.count == 3 { break }
                    let frontages = Self.frontageRoads(for: workplace.coordinate, roadSet: roadSet)
                    let reachableFrontages = frontages.filter {
                        roadComponents[$0].map(originComponents.contains) ?? false
                    }
                    guard !reachableFrontages.isEmpty else { continue }
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
                    let weight = utilization * (0.65 + demand * 0.35)
                    if weight > 0 {
                        weightedDestinations.append(
                            WeightedDestination(frontages: reachableFrontages, weight: weight)
                        )
                    }
                }
                let totalWeight = weightedDestinations.reduce(0) { $0 + $1.weight }
                guard totalWeight > 0 else { continue }

                let averageDestinationWeight = totalWeight / Double(weightedDestinations.count)
                let sourceDemand = Self.utilization(
                    of: residence,
                    aggregateFallback: residentialFallbackUtilization
                )
                    * Self.clamp(averageDestinationWeight)
                for destination in weightedDestinations {
                    var remainingDemand = sourceDemand * destination.weight / totalWeight
                    while remainingDemand > 0.000_001 {
                        let quantum = min(0.20, remainingDemand)
                        guard let route = Self.leastCostRoute(
                            from: origins,
                            to: Set(destination.frontages),
                            roadSet: roadSet,
                            loads: loads,
                            capacities: capacities,
                            width: width,
                            height: height
                        ) else {
                            break
                        }
                        for coordinate in route {
                            loads[coordinate.y * width + coordinate.x] += quantum
                        }
                        remainingDemand -= quantum
                    }
                }
            }
        }

        var resolvedRoads = Array<CityTrafficRoadReading?>(repeating: nil, count: sampleCount)
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
        roadSamples = resolvedRoads

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
                exposure: exposure
            )
        }
        placeSamples = resolvedPlaces
    }

    private struct WeightedDestination {
        let frontages: [GridCoordinate]
        let weight: Double
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

    private static func leastCostRoute(
        from origins: [GridCoordinate],
        to destinations: Set<GridCoordinate>,
        roadSet: Set<GridCoordinate>,
        loads: [Double],
        capacities: [Double],
        width: Int,
        height: Int
    ) -> [GridCoordinate]? {
        let sampleCount = width * height
        var distances = Array(repeating: Double.infinity, count: sampleCount)
        var predecessors = Array<Int?>(repeating: nil, count: sampleCount)
        var queue = RouteMinHeap()

        for origin in origins.sorted(by: rowMajor) {
            let index = origin.y * width + origin.x
            distances[index] = 0
            queue.insert(RouteQueueEntry(index: index, cost: 0))
        }

        var destinationIndex: Int?
        while let entry = queue.removeMinimum() {
            guard entry.cost <= distances[entry.index] + 0.000_001 else { continue }
            let coordinate = GridCoordinate(x: entry.index % width, y: entry.index / width)
            if destinations.contains(coordinate) {
                destinationIndex = entry.index
                break
            }

            for neighbor in orthogonalNeighbors(of: coordinate).sorted(by: rowMajor)
            where neighbor.x >= 0 && neighbor.y >= 0
                && neighbor.x < width && neighbor.y < height
                && roadSet.contains(neighbor) {
                let neighborIndex = neighbor.y * width + neighbor.x
                let utilization = loads[neighborIndex] / max(0.1, capacities[neighborIndex])
                let candidateCost = entry.cost + 1 + utilization * 1.5
                let currentCost = distances[neighborIndex]
                let predecessor = predecessors[neighborIndex] ?? Int.max
                if candidateCost < currentCost - 0.000_001
                    || (abs(candidateCost - currentCost) <= 0.000_001 && entry.index < predecessor) {
                    distances[neighborIndex] = candidateCost
                    predecessors[neighborIndex] = entry.index
                    queue.insert(RouteQueueEntry(index: neighborIndex, cost: candidateCost))
                }
            }
        }

        guard var current = destinationIndex else { return nil }
        var route: [GridCoordinate] = []
        while true {
            route.append(GridCoordinate(x: current % width, y: current / width))
            guard let predecessor = predecessors[current] else { break }
            current = predecessor
        }
        return route.reversed()
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

private struct RouteQueueEntry: Equatable {
    let index: Int
    let cost: Double

    static func orderedBefore(_ lhs: Self, _ rhs: Self) -> Bool {
        if abs(lhs.cost - rhs.cost) > 0.000_001 { return lhs.cost < rhs.cost }
        return lhs.index < rhs.index
    }
}

private struct RouteMinHeap {
    private var storage: [RouteQueueEntry] = []

    mutating func insert(_ entry: RouteQueueEntry) {
        storage.append(entry)
        var child = storage.count - 1
        while child > 0 {
            let parent = (child - 1) / 2
            guard RouteQueueEntry.orderedBefore(storage[child], storage[parent]) else { break }
            storage.swapAt(child, parent)
            child = parent
        }
    }

    mutating func removeMinimum() -> RouteQueueEntry? {
        guard !storage.isEmpty else { return nil }
        if storage.count == 1 { return storage.removeLast() }
        let minimum = storage[0]
        storage[0] = storage.removeLast()
        var parent = 0
        while true {
            let left = parent * 2 + 1
            let right = left + 1
            var candidate = parent
            if left < storage.count,
               RouteQueueEntry.orderedBefore(storage[left], storage[candidate]) {
                candidate = left
            }
            if right < storage.count,
               RouteQueueEntry.orderedBefore(storage[right], storage[candidate]) {
                candidate = right
            }
            guard candidate != parent else { break }
            storage.swapAt(parent, candidate)
            parent = candidate
        }
        return minimum
    }
}
