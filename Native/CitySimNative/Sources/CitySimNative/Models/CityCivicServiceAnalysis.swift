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
    static let maximumRoadDistance = CityCivicServiceFundingPolicy.standard.maximumRoadDistance
    static let healthyCoverageThreshold = 0.75

    let width: Int
    let height: Int
    let samples: [CityLocationCivicService?]
    let citywideResidentialCoverage: Double
    let citywideResidentialFireCoverage: Double
    let citywideCommercialPoliceCoverage: Double
    let citywideResidentialSchoolCoverage: Double

    func outcomeCoverage(for kind: BuildingKind) -> Double? {
        switch kind {
        case .fireStation: citywideResidentialFireCoverage
        case .policeStation: citywideCommercialPoliceCoverage
        case .school: citywideResidentialSchoolCoverage
        default: nil
        }
    }

    subscript(_ coordinate: GridCoordinate) -> CityLocationCivicService? {
        guard coordinate.x >= 0, coordinate.y >= 0,
              coordinate.x < width, coordinate.y < height,
              samples.count == width * height else { return nil }
        return samples[coordinate.y * width + coordinate.x]
    }

    init(state: CityGameState, retainsLocationSamples: Bool = true) {
        width = state.gridWidth
        height = state.gridHeight
        let fundingPolicy = state.effectiveCivicServiceFundingPolicy
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
                        height: state.gridHeight,
                        maximumRoadDistance: fundingPolicy.maximumRoadDistance
                    )
                )
            }

        var resolved = retainsLocationSamples
            ? Array<CityLocationCivicService?>(repeating: nil, count: width * height)
            : []
        let completedPlaces = state.tiles
            .filter(Self.isCompletedPlace)
            .sorted { Self.rowMajor($0.coordinate, $1.coordinate) }
        var residentialOccupancy = 0
        var commercialOccupancy = 0
        for tile in completedPlaces {
            if tile.kind == .residential {
                residentialOccupancy += max(0, tile.occupancy)
            } else if tile.kind == .commercial {
                commercialOccupancy += max(0, tile.occupancy)
            }
        }
        let useResidentialCapacity = residentialOccupancy == 0 && state.population > 0
        let useCommercialCapacity = commercialOccupancy == 0 && state.jobs > 0
        var residentialCombined = 0.0
        var residentialFire = 0.0
        var residentialSchool = 0.0
        var residentialWeight = 0.0
        var commercialPolice = 0.0
        var commercialWeight = 0.0
        for tile in completedPlaces {
            let frontages = Self.frontageRoads(for: tile.coordinate, roadSet: roadSet)
            var fire = 0.0
            var police = 0.0
            var school = 0.0
            for source in sources {
                let coverage = Self.coverage(
                    from: source,
                    to: frontages,
                    width: width,
                    maximumRoadDistance: fundingPolicy.maximumRoadDistance
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
            if retainsLocationSamples {
                resolved[tile.coordinate.y * width + tile.coordinate.x] = service
            }
            if tile.kind == .residential {
                let weight = Double(
                    useResidentialCapacity
                        ? 280 * max(1, tile.level)
                        : max(0, tile.occupancy)
                )
                residentialCombined += service.combined * weight
                residentialFire += service.fire * weight
                residentialSchool += service.school * weight
                residentialWeight += weight
            } else if tile.kind == .commercial {
                let weight = Double(
                    useCommercialCapacity
                        ? CitySimulation.commercialJobCapacity * max(1, tile.level)
                        : max(0, tile.occupancy)
                )
                commercialPolice += service.police * weight
                commercialWeight += weight
            }
        }
        samples = resolved
        citywideResidentialCoverage = residentialWeight > 0
            ? Self.clamp(residentialCombined / residentialWeight)
            : 0
        citywideResidentialFireCoverage = residentialWeight > 0
            ? Self.clamp(residentialFire / residentialWeight)
            : 0
        citywideResidentialSchoolCoverage = residentialWeight > 0
            ? Self.clamp(residentialSchool / residentialWeight)
            : 0
        citywideCommercialPoliceCoverage = commercialWeight > 0
            ? Self.clamp(commercialPolice / commercialWeight)
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
        width: Int,
        maximumRoadDistance: Int
    ) -> Double {
        var roadDistance = Int.max
        for frontage in frontages {
            roadDistance = min(
                roadDistance,
                source.roadDistances[frontage.y * width + frontage.x]
            )
        }
        guard roadDistance <= maximumRoadDistance else { return 0 }
        let reach = 1 - Double(roadDistance) / Double(maximumRoadDistance + 1)
        return clamp(reach * source.condition)
    }

    private static func roadDistances(
        from origins: [GridCoordinate],
        roadSet: Set<GridCoordinate>,
        width: Int,
        height: Int,
        maximumRoadDistance: Int
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
