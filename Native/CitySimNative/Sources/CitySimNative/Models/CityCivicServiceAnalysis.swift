import Foundation

struct CityLocationCivicService: Equatable, Sendable {
    let fire: Double
    let police: Double
    let school: Double
    let combined: Double

    func coverage(for kind: BuildingKind) -> Double? {
        switch kind {
        case .fireStation: fire
        case .policeStation: police
        case .school: school
        default: nil
        }
    }

    var weakestService: BuildingKind {
        let ordered: [(BuildingKind, Double)] = [
            (.fireStation, fire),
            (.policeStation, police),
            (.school, school)
        ]
        return ordered.min { lhs, rhs in
            if abs(lhs.1 - rhs.1) > 0.000_001 { return lhs.1 < rhs.1 }
            return Self.serviceOrder(lhs.0) < Self.serviceOrder(rhs.0)
        }!.0
    }

    private static func serviceOrder(_ kind: BuildingKind) -> Int {
        switch kind {
        case .fireStation: 0
        case .policeStation: 1
        case .school: 2
        default: 3
        }
    }
}

struct CityCivicServiceAnalysis: Equatable, Sendable {
    static let maximumRoadDistance = 12
    static let healthyCoverageThreshold = 0.75

    let width: Int
    let height: Int
    let samples: [CityLocationCivicService?]
    let citywideResidentialCoverage: Double

    subscript(_ coordinate: GridCoordinate) -> CityLocationCivicService? {
        guard coordinate.x >= 0, coordinate.y >= 0,
              coordinate.x < width, coordinate.y < height else { return nil }
        return samples[coordinate.y * width + coordinate.x]
    }

    init(state: CityGameState) {
        width = state.gridWidth
        height = state.gridHeight
        let roadCoordinates = state.tiles
            .filter { $0.kind == .road }
            .map(\.coordinate)
            .sorted(by: Self.rowMajor)
        let roadSet = Set(roadCoordinates)
        let sources = state.tiles
            .filter {
                Self.serviceKinds.contains($0.kind)
                    && $0.constructionProgress >= 1
            }
            .sorted { Self.rowMajor($0.coordinate, $1.coordinate) }
            .compactMap { tile -> ServiceSource? in
                let frontage = Self.frontageRoads(for: tile.coordinate, roadSet: roadSet)
                guard !frontage.isEmpty else { return nil }
                return ServiceSource(
                    kind: tile.kind,
                    condition: Self.clamp(tile.condition),
                    roadDistances: Self.roadDistances(
                        from: frontage,
                        roadSet: roadSet,
                        width: state.gridWidth,
                        height: state.gridHeight
                    )
                )
            }

        var resolved = Array<CityLocationCivicService?>(
            repeating: nil,
            count: width * height
        )
        let completedPlaces = state.tiles
            .filter(Self.isCompletedPlace)
            .sorted { Self.rowMajor($0.coordinate, $1.coordinate) }
        for tile in completedPlaces {
            let frontages = Self.frontageRoads(for: tile.coordinate, roadSet: roadSet)
            var fire = 0.0
            var police = 0.0
            var school = 0.0
            for source in sources {
                let coverage = Self.coverage(
                    from: source,
                    to: frontages,
                    width: width
                )
                switch source.kind {
                case .fireStation:
                    fire = max(fire, coverage)
                case .policeStation:
                    police = max(police, coverage)
                case .school:
                    school = max(school, coverage)
                default:
                    break
                }
            }
            let service = CityLocationCivicService(
                fire: fire,
                police: police,
                school: school,
                combined: (fire + police + school) / 3
            )
            resolved[tile.coordinate.y * width + tile.coordinate.x] = service
        }
        samples = resolved

        let residences = completedPlaces.filter { $0.kind == .residential }
        let explicitOccupancy = residences.reduce(0) { $0 + max(0, $1.occupancy) }
        let useCapacityFallback = explicitOccupancy == 0 && state.population > 0
        var weightedCoverage = 0.0
        var totalWeight = 0.0
        for residence in residences {
            let weight: Double
            if useCapacityFallback {
                weight = Double(280 * max(1, residence.level))
            } else {
                weight = Double(max(0, residence.occupancy))
            }
            guard weight > 0,
                  let service = resolved[residence.coordinate.y * width + residence.coordinate.x]
            else { continue }
            weightedCoverage += service.combined * weight
            totalWeight += weight
        }
        citywideResidentialCoverage = totalWeight > 0
            ? Self.clamp(weightedCoverage / totalWeight)
            : 0
    }

    private struct ServiceSource {
        let kind: BuildingKind
        let condition: Double
        let roadDistances: [Int]
    }

    private static let serviceKinds: Set<BuildingKind> = [
        .fireStation, .policeStation, .school
    ]

    private static func coverage(
        from source: ServiceSource,
        to frontages: [GridCoordinate],
        width: Int
    ) -> Double {
        let roadDistance = frontages
            .map { source.roadDistances[$0.y * width + $0.x] }
            .min() ?? Int.max
        guard roadDistance <= maximumRoadDistance else { return 0 }
        let reach = 1 - Double(roadDistance) / Double(maximumRoadDistance + 1)
        return clamp(reach * source.condition)
    }

    private static func roadDistances(
        from origins: [GridCoordinate],
        roadSet: Set<GridCoordinate>,
        width: Int,
        height: Int
    ) -> [Int] {
        var distances = Array(repeating: Int.max, count: width * height)
        var queue: [GridCoordinate] = []
        for origin in origins.sorted(by: rowMajor) {
            let index = origin.y * width + origin.x
            guard distances[index] != 0 else { continue }
            distances[index] = 0
            queue.append(origin)
        }

        var cursor = 0
        while cursor < queue.count {
            let current = queue[cursor]
            cursor += 1
            let currentIndex = current.y * width + current.x
            let nextDistance = distances[currentIndex] + 1
            guard nextDistance <= maximumRoadDistance else { continue }
            for neighbor in orthogonalNeighbors(of: current).sorted(by: rowMajor)
            where neighbor.x >= 0 && neighbor.y >= 0
                && neighbor.x < width && neighbor.y < height
                && roadSet.contains(neighbor) {
                let index = neighbor.y * width + neighbor.x
                guard nextDistance < distances[index] else { continue }
                distances[index] = nextDistance
                queue.append(neighbor)
            }
        }
        return distances
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

    private static func isCompletedPlace(_ tile: CityTile) -> Bool {
        tile.kind != .empty
            && tile.kind != .road
            && tile.constructionProgress >= 1
    }

    private static func rowMajor(_ lhs: CityTile, _ rhs: CityTile) -> Bool {
        rowMajor(lhs.coordinate, rhs.coordinate)
    }

    private static func rowMajor(_ lhs: GridCoordinate, _ rhs: GridCoordinate) -> Bool {
        if lhs.y != rhs.y { return lhs.y < rhs.y }
        return lhs.x < rhs.x
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
