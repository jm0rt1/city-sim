import Foundation
import XCTest
@testable import CitySimNative

final class StarterDistrictTests: XCTestCase {
    func testStarterTownHasExactConnectedThreeBlockTopologyWithoutRoadDeadEnds() {
        let state = CityGameState.newCity(seed: 42)
        let roadCoordinates = Set(
            state.tiles
                .filter { $0.kind == .road }
                .map(\.coordinate)
        )

        var expectedRoads = Set<GridCoordinate>()
        for x in 4..<17 {
            expectedRoads.insert(GridCoordinate(x: x, y: 9))
            expectedRoads.insert(GridCoordinate(x: x, y: 12))
        }
        for y in 9...12 {
            expectedRoads.insert(GridCoordinate(x: 4, y: y))
            expectedRoads.insert(GridCoordinate(x: 12, y: y))
            expectedRoads.insert(GridCoordinate(x: 16, y: y))
        }
        expectedRoads.formUnion([
            GridCoordinate(x: 8, y: 10),
            GridCoordinate(x: 8, y: 11),
        ])

        XCTAssertEqual(roadCoordinates, expectedRoads)
        XCTAssertEqual(roadCoordinates.count, 34)
        XCTAssertEqual(connectedRoads(from: GridCoordinate(x: 4, y: 9), in: state), roadCoordinates)
        XCTAssertTrue(roadCoordinates.allSatisfy { coordinate in
            state.neighbors(of: coordinate).filter { $0.kind == .road }.count >= 2
        })

        let occupied = state.tiles.filter { ![.empty, .road].contains($0.kind) }
        XCTAssertEqual(occupied.count, 12)
        XCTAssertEqual(occupied.filter { $0.kind == .residential }.count, 6)
        XCTAssertEqual(occupied.filter { $0.kind == .commercial }.count, 1)
        XCTAssertEqual(occupied.filter { $0.kind == .industrial }.count, 1)
        XCTAssertEqual(occupied.filter { $0.kind == .park }.count, 1)
        XCTAssertEqual(occupied.filter { $0.kind == .powerPlant }.count, 1)
        XCTAssertEqual(occupied.filter { $0.kind == .waterTower }.count, 1)
        XCTAssertEqual(occupied.filter { $0.kind == .cityHall }.count, 1)
        XCTAssertTrue(occupied.allSatisfy { tile in
            state.neighbors(of: tile.coordinate).contains { $0.kind == .road }
        })

        let expectedOccupied: [GridCoordinate: BuildingKind] = [
            GridCoordinate(x: 3, y: 10): .residential,
            GridCoordinate(x: 6, y: 10): .residential,
            GridCoordinate(x: 6, y: 11): .residential,
            GridCoordinate(x: 9, y: 10): .residential,
            GridCoordinate(x: 10, y: 11): .residential,
            GridCoordinate(x: 11, y: 11): .cityHall,
            GridCoordinate(x: 13, y: 11): .commercial,
            GridCoordinate(x: 14, y: 11): .industrial,
            GridCoordinate(x: 17, y: 10): .residential,
            GridCoordinate(x: 11, y: 13): .park,
            GridCoordinate(x: 13, y: 13): .powerPlant,
            GridCoordinate(x: 15, y: 13): .waterTower,
        ]
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: occupied.map { ($0.coordinate, $0.kind) }),
            expectedOccupied
        )

        let blocks = enclosedBlocks(in: state)
        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks.map(\.vacantCount), [4, 3, 4])
        XCTAssertEqual(blocks.map(\.occupiedCount), [2, 3, 2])
        XCTAssertTrue(blocks.allSatisfy { $0.vacantCount >= 2 })
        XCTAssertTrue(occupied.filter { $0.coordinate.y == 13 }.map(\.kind).contains(.park))
        XCTAssertTrue(occupied.filter { $0.coordinate.y == 13 }.map(\.kind).contains(.powerPlant))
        XCTAssertTrue(occupied.filter { $0.coordinate.y == 13 }.map(\.kind).contains(.waterTower))
    }

    func testStarterTownOffersExactlyFortyValidGrowthFrontagesAcrossAllBlocks() {
        let state = CityGameState.newCity(seed: 42)
        let commercialChoices = validCoordinates(for: .commercial, in: state)
        let industrialChoices = validCoordinates(for: .industrial, in: state)

        XCTAssertEqual(commercialChoices, industrialChoices)
        XCTAssertEqual(commercialChoices.count, 40)
        XCTAssertGreaterThanOrEqual(commercialChoices.filter { $0.x < 12 }.count, 8)
        XCTAssertGreaterThanOrEqual(commercialChoices.filter { $0.x > 12 }.count, 8)
        XCTAssertGreaterThanOrEqual(Set(commercialChoices.map(\.y)).count, 4)
    }

    func testStarterTownResidentialFrontagesUseAllAuthoredDirectionsWithoutAdjacentAliases() throws {
        let state = CityGameState.newCity(seed: 42)
        let residential = state.tiles.filter { $0.kind == .residential }
        let expectedNewFrontages: [GridCoordinate: RoadConnectionMask] = [
            GridCoordinate(x: 6, y: 10): .north,
            GridCoordinate(x: 6, y: 11): .south,
            GridCoordinate(x: 3, y: 10): .east,
            GridCoordinate(x: 17, y: 10): .west,
        ]
        let identities = try Dictionary(uniqueKeysWithValues: residential.map { tile in
            let roads = RoadConnectionMask.resolving(at: tile.coordinate, in: state)
            let identity = try XCTUnwrap(
                ResidentialGeneratedAssetIdentity(level: tile.level, adjacentRoads: roads)
            )
            return (tile.coordinate, identity)
        })

        for (coordinate, frontage) in expectedNewFrontages {
            XCTAssertEqual(identities[coordinate]?.frontage, frontage)
        }
        XCTAssertEqual(identities[GridCoordinate(x: 9, y: 10)]?.frontage, .north)
        XCTAssertEqual(identities[GridCoordinate(x: 10, y: 11)]?.frontage, .south)
        XCTAssertEqual(
            Set(expectedNewFrontages.keys.compactMap { identities[$0]?.direction }),
            Set(["north", "east", "south", "west"])
        )

        for tile in residential {
            for neighbor in state.neighbors(of: tile.coordinate)
                where neighbor.kind == .residential
                    && tile.coordinate.id < neighbor.coordinate.id {
                XCTAssertNotEqual(
                    identities[tile.coordinate]?.logicalID,
                    identities[neighbor.coordinate]?.logicalID,
                    "\(tile.coordinate) and \(neighbor.coordinate) must not read as an adjacent source alias"
                )
            }
        }
    }

    func testFirstGrowthChoiceCommitsEitherStrategyAtNextDailyReview() throws {
        let opening = CityGameState.newCity(seed: 42)
        XCTAssertNil(opening.progression?.strategy)

        var commerce = opening
        try buildFirstValid(.commercial, in: &commerce)
        for _ in 0..<3 {
            CitySimulation.step(&commerce)
            XCTAssertNil(commerce.progression?.strategy)
        }
        CitySimulation.step(&commerce)
        XCTAssertEqual(commerce.tick, 4)
        XCTAssertEqual(commerce.progression?.strategy?.committedStrategy, .commercialStewardship)

        var industry = opening
        try buildFirstValid(.industrial, in: &industry)
        for _ in 0..<4 { CitySimulation.step(&industry) }
        XCTAssertEqual(industry.tick, 4)
        XCTAssertEqual(industry.progression?.strategy?.committedStrategy, .industrialExpansion)

        XCTAssertLessThan(4.0 * 0.42, 120)
    }

    func testOpeningPressureKeepsUtilitiesSafeAndMakesBothRoutesConsequential() throws {
        let opening = CityGameState.newCity(seed: 42)
        let openingAnalytics = CityAnalytics(state: opening)

        XCTAssertEqual(opening.treasury, 32_000)
        XCTAssertEqual(opening.population, 300)
        XCTAssertEqual(opening.jobs, 190)
        XCTAssertEqual(openingAnalytics.jobShortfall, 20)
        XCTAssertEqual(openingAnalytics.powerHeadroom, 54)
        XCTAssertEqual(openingAnalytics.waterHeadroom, 48)
        XCTAssertEqual(opening.taxRate, 0.10, accuracy: 0.000_001)
        XCTAssertEqual(openingAnalytics.projectedBalance, -126.2, accuracy: 0.001)
        XCTAssertEqual(openingAnalytics.operatingRunwayCycles ?? 0, 253.57, accuracy: 0.01)
        XCTAssertTrue(opening.messages.contains {
            $0.title == "A Town at the Crossroads"
                && $0.detail.contains("three-block starter town")
                && $0.detail.contains("$126 operating deficit")
                && $0.detail.contains("Choose Commercial")
                && $0.detail.contains("Industrial")
        })

        var commerce = opening
        try buildFirstValid(.commercial, in: &commerce)
        for _ in 0..<4 { CitySimulation.step(&commerce) }
        let commerceAnalytics = CityAnalytics(state: commerce)

        var industry = opening
        try buildFirstValid(.industrial, in: &industry)
        for _ in 0..<4 { CitySimulation.step(&industry) }
        let industryAnalytics = CityAnalytics(state: industry)

        XCTAssertGreaterThan(commerceAnalytics.projectedBalance, openingAnalytics.projectedBalance)
        XCTAssertGreaterThan(industryAnalytics.projectedBalance, commerceAnalytics.projectedBalance)
        XCTAssertGreaterThan(commerceAnalytics.utilityReserve, 0.1)
        XCTAssertGreaterThan(industryAnalytics.utilityReserve, 0.1)
        XCTAssertGreaterThan(industryAnalytics.pollutionPressure, commerceAnalytics.pollutionPressure)
        XCTAssertGreaterThan(industryAnalytics.jobCapacity, commerceAnalytics.jobCapacity)
    }

    func testHiringBottleneckStaysSilentWhenCapacityIsHealthyDespiteFilledJobsLag() {
        var state = CityGameState.newCity(seed: 42)
        state.jobs = 170

        let analytics = CityAnalytics(state: state)
        XCTAssertLessThan(analytics.employmentRate, 0.82)
        XCTAssertGreaterThanOrEqual(
            Double(analytics.jobCapacity) / Double(analytics.workforceTarget),
            0.82,
            "Available capacity must prove that another workplace is unnecessary"
        )
        XCTAssertNil(CitySimulation.hiringBottleneckWarning(in: state))
    }

    func testHiringBottleneckReportsCapacityGapAndBothGrowthRoutes() throws {
        var state = CityGameState.newCity(seed: 42)
        for index in state.tiles.indices where state.tiles[index].kind == .commercial {
            state.tiles[index].constructionProgress = 0
        }

        let analytics = CityAnalytics(state: state)
        XCTAssertEqual(analytics.jobCapacity, 110)
        XCTAssertLessThan(
            Double(analytics.jobCapacity) / Double(analytics.workforceTarget),
            0.82,
            "Available capacity must prove that another workplace is needed"
        )

        let warning = try XCTUnwrap(CitySimulation.hiringBottleneckWarning(in: state))
        XCTAssertEqual(warning.title, "Hiring Bottleneck")
        XCTAssertEqual(warning.severity, .warning)
        XCTAssertEqual(
            warning.detail,
            "Job capacity covers 52% of the workforce target: 110 available jobs for 210 workers, a 100-job capacity gap. Add Commercial or Industrial workplaces to close it: Commercial is cleaner; Industrial adds jobs faster but brings more pollution and utility load."
        )
    }

    func testDayOneAndDayElevenFreezeNoChoiceAndBothStrategyLedgers() throws {
        var noChoice = CityGameState.newCity(seed: 42)
        var commerce = noChoice
        var industry = noChoice
        try buildFirstValid(.commercial, in: &commerce)
        try buildFirstValid(.industrial, in: &industry)

        assertLedger(
            noChoice,
            expected: ExpectedLedger(
                tick: 0, treasury: 32_000, population: 300, jobs: 190,
                jobCapacity: 190, balance: -126.2,
                residentialDemand: 0.72, commercialDemand: 0.68, industrialDemand: 0.56,
                happiness: 58, pollution: 28, powerUsed: 246, waterUsed: 222,
                utilityReserve: 0.17777777777777778, strategy: nil
            )
        )
        assertLedger(
            commerce,
            expected: ExpectedLedger(
                tick: 0, treasury: 29_600, population: 300, jobs: 190,
                jobCapacity: 190, balance: -126.2,
                residentialDemand: 0.72, commercialDemand: 0.68, industrialDemand: 0.56,
                happiness: 58, pollution: 28, powerUsed: 246, waterUsed: 222,
                utilityReserve: 0.17777777777777778, strategy: nil
            )
        )
        assertLedger(
            industry,
            expected: ExpectedLedger(
                tick: 0, treasury: 28_800, population: 300, jobs: 190,
                jobCapacity: 190, balance: -126.2,
                residentialDemand: 0.72, commercialDemand: 0.68, industrialDemand: 0.56,
                happiness: 58, pollution: 28, powerUsed: 246, waterUsed: 222,
                utilityReserve: 0.17777777777777778, strategy: nil
            )
        )

        advanceToTick(&noChoice, tick: 40)
        advanceToTick(&commerce, tick: 40)
        advanceToTick(&industry, tick: 40)

        assertLedger(
            noChoice,
            expected: ExpectedLedger(
                tick: 40, treasury: 30_754.5, population: 310, jobs: 190,
                jobCapacity: 190, balance: -123.2,
                residentialDemand: 0.6196509955132314,
                commercialDemand: 0.7073333333333334,
                industrialDemand: 0.6925396825396825,
                happiness: 62.45715789037091, pollution: 28,
                powerUsed: 253, waterUsed: 228,
                utilityReserve: 0.15555555555555556, strategy: nil
            )
        )
        assertLedger(
            commerce,
            expected: ExpectedLedger(
                tick: 40, treasury: 29_873.5, population: 310, jobs: 216,
                jobCapacity: 270, balance: 32,
                residentialDemand: 0.6530949427435262,
                commercialDemand: 0.5090000000000001,
                industrialDemand: 0.5864285714285713,
                happiness: 63.82079198409365, pollution: 28,
                powerUsed: 260, waterUsed: 233,
                utilityReserve: 0.13333333333333333,
                strategy: .commercialStewardship
            )
        )
        assertLedger(
            industry,
            expected: ExpectedLedger(
                tick: 40, treasury: 29_537.5, population: 310, jobs: 216,
                jobCapacity: 300, balance: 78.4,
                residentialDemand: 0.6039826468934122,
                commercialDemand: 0.5990000000000001,
                industrialDemand: 0.5334285714285714,
                happiness: 59.675070565077704, pollution: 36,
                powerUsed: 273, waterUsed: 240,
                utilityReserve: 0.09, strategy: .industrialExpansion
            )
        )
    }

    func testStarterDistrictIsSeedRepeatableAndCodableWithoutNewStateShape() throws {
        let first = CityGameState.newCity(seed: 42)
        let second = CityGameState.newCity(seed: 42)
        XCTAssertEqual(first, second)

        let roundTrip = try JSONDecoder().decode(
            CityGameState.self,
            from: JSONEncoder().encode(first)
        )
        XCTAssertEqual(roundTrip, first)
        XCTAssertEqual(roundTrip.progression, CityProgressionState())

        let firstFingerprint = try CityStateFingerprinter.fingerprint(first, version: 1)
        let secondFingerprint = try CityStateFingerprinter.fingerprint(second, version: 1)
        XCTAssertEqual(firstFingerprint, secondFingerprint)
    }

    private struct ExpectedLedger {
        let tick: Int
        let treasury: Double
        let population: Int
        let jobs: Int
        let jobCapacity: Int
        let balance: Double
        let residentialDemand: Double
        let commercialDemand: Double
        let industrialDemand: Double
        let happiness: Double
        let pollution: Double
        let powerUsed: Int
        let waterUsed: Int
        let utilityReserve: Double
        let strategy: CityStrategy?
    }

    private func assertLedger(
        _ state: CityGameState,
        expected: ExpectedLedger,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let analytics = CityAnalytics(state: state)
        XCTAssertEqual(state.tick, expected.tick, file: file, line: line)
        XCTAssertEqual(state.treasury, expected.treasury, accuracy: 0.000_001, file: file, line: line)
        XCTAssertEqual(state.population, expected.population, file: file, line: line)
        XCTAssertEqual(state.jobs, expected.jobs, file: file, line: line)
        XCTAssertEqual(analytics.jobCapacity, expected.jobCapacity, file: file, line: line)
        XCTAssertEqual(analytics.projectedBalance, expected.balance, accuracy: 0.000_001, file: file, line: line)
        XCTAssertEqual(state.demand.residential, expected.residentialDemand, accuracy: 0.000_001, file: file, line: line)
        XCTAssertEqual(state.demand.commercial, expected.commercialDemand, accuracy: 0.000_001, file: file, line: line)
        XCTAssertEqual(state.demand.industrial, expected.industrialDemand, accuracy: 0.000_001, file: file, line: line)
        XCTAssertEqual(state.happiness, expected.happiness, accuracy: 0.000_001, file: file, line: line)
        XCTAssertEqual(analytics.pollutionPressure, expected.pollution, accuracy: 0.000_001, file: file, line: line)
        XCTAssertEqual(state.powerUsed, expected.powerUsed, file: file, line: line)
        XCTAssertEqual(state.waterUsed, expected.waterUsed, file: file, line: line)
        XCTAssertEqual(analytics.utilityReserve, expected.utilityReserve, accuracy: 0.000_001, file: file, line: line)
        XCTAssertEqual(state.progression?.strategy?.committedStrategy, expected.strategy, file: file, line: line)
    }

    private func advanceToTick(_ state: inout CityGameState, tick: Int) {
        while state.tick < tick {
            CitySimulation.step(&state)
        }
    }

    private func connectedRoads(
        from start: GridCoordinate,
        in state: CityGameState
    ) -> Set<GridCoordinate> {
        var visited: Set<GridCoordinate> = []
        var pending = [start]

        while let coordinate = pending.popLast() {
            guard visited.insert(coordinate).inserted else { continue }
            pending.append(contentsOf: state.neighbors(of: coordinate)
                .filter { $0.kind == .road && !visited.contains($0.coordinate) }
                .map(\.coordinate))
        }
        return visited
    }

    private struct EnclosedBlock {
        let firstCoordinate: GridCoordinate
        let vacantCount: Int
        let occupiedCount: Int
    }

    private func enclosedBlocks(in state: CityGameState) -> [EnclosedBlock] {
        let nonRoad = Set(state.tiles.filter { $0.kind != .road }.map(\.coordinate))
        var exterior = Set<GridCoordinate>()
        var pending = Array(nonRoad.filter {
            $0.x == 0 || $0.y == 0
                || $0.x == state.gridWidth - 1
                || $0.y == state.gridHeight - 1
        })
        while let coordinate = pending.popLast() {
            guard exterior.insert(coordinate).inserted else { continue }
            pending.append(contentsOf: state.neighbors(of: coordinate)
                .map(\.coordinate)
                .filter { nonRoad.contains($0) && !exterior.contains($0) })
        }

        var remaining = nonRoad.subtracting(exterior)
        var blocks: [EnclosedBlock] = []
        while let origin = remaining.min(by: { ($0.y, $0.x) < ($1.y, $1.x) }) {
            remaining.remove(origin)
            var component = Set([origin])
            var frontier = [origin]
            while let coordinate = frontier.popLast() {
                for neighbor in state.neighbors(of: coordinate).map(\.coordinate)
                    where remaining.remove(neighbor) != nil {
                    component.insert(neighbor)
                    frontier.append(neighbor)
                }
            }
            let vacantCount = component.filter { state.tile(at: $0)?.kind == .empty }.count
            guard vacantCount >= 2 else { continue }
            blocks.append(EnclosedBlock(
                firstCoordinate: origin,
                vacantCount: vacantCount,
                occupiedCount: component.count - vacantCount
            ))
        }
        return blocks.sorted {
            ($0.firstCoordinate.y, $0.firstCoordinate.x)
                < ($1.firstCoordinate.y, $1.firstCoordinate.x)
        }
    }

    private func validCoordinates(
        for kind: BuildingKind,
        in state: CityGameState
    ) -> [GridCoordinate] {
        state.tiles.compactMap { tile in
            guard case .success = CitySimulation.validateBuild(kind, at: tile.coordinate, in: state) else {
                return nil
            }
            return tile.coordinate
        }
    }

    private func buildFirstValid(
        _ kind: BuildingKind,
        in state: inout CityGameState
    ) throws {
        guard let coordinate = validCoordinates(for: kind, in: state).first else {
            throw BuildRejection.outsideMap
        }
        if case .failure(let rejection) = CitySimulation.build(kind, at: coordinate, in: &state) {
            throw rejection
        }
    }
}
