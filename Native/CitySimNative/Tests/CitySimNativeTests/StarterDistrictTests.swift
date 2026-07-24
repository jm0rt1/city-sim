import Foundation
import XCTest
@testable import CitySimNative

final class StarterDistrictTests: XCTestCase {
    func testStarterDistrictIsConnectedAcrossTwoOccupiedBlocksWithoutRoadDeadEnds() {
        let state = CityGameState.newCity(seed: 42)
        let roadCoordinates = Set(
            state.tiles
                .filter { $0.kind == .road }
                .map(\.coordinate)
        )

        XCTAssertEqual(roadCoordinates.count, 32)
        XCTAssertEqual(connectedRoads(from: GridCoordinate(x: 4, y: 9), in: state), roadCoordinates)
        XCTAssertTrue(roadCoordinates.allSatisfy { coordinate in
            state.neighbors(of: coordinate).filter { $0.kind == .road }.count >= 2
        })

        let occupied = state.tiles.filter { ![.empty, .road].contains($0.kind) }
        XCTAssertEqual(occupied.count, 8)
        XCTAssertEqual(occupied.filter { $0.kind == .residential }.count, 2)
        XCTAssertEqual(occupied.filter { $0.kind == .commercial }.count, 1)
        XCTAssertEqual(occupied.filter { $0.kind == .industrial }.count, 1)
        XCTAssertEqual(occupied.filter { $0.kind == .park }.count, 1)
        XCTAssertEqual(occupied.filter { $0.kind == .powerPlant }.count, 1)
        XCTAssertEqual(occupied.filter { $0.kind == .waterTower }.count, 1)
        XCTAssertEqual(occupied.filter { $0.kind == .cityHall }.count, 1)
        XCTAssertTrue(occupied.allSatisfy { tile in
            state.neighbors(of: tile.coordinate).contains { $0.kind == .road }
        })

        let leftBlock = occupied.filter { (5...11).contains($0.coordinate.x) && (10...11).contains($0.coordinate.y) }
        let rightBlock = occupied.filter { (13...15).contains($0.coordinate.x) && (10...11).contains($0.coordinate.y) }
        XCTAssertGreaterThanOrEqual(leftBlock.count, 3)
        XCTAssertGreaterThanOrEqual(rightBlock.count, 2)
        XCTAssertTrue(occupied.filter { $0.coordinate.y == 13 }.map(\.kind).contains(.park))
        XCTAssertTrue(occupied.filter { $0.coordinate.y == 13 }.map(\.kind).contains(.powerPlant))
        XCTAssertTrue(occupied.filter { $0.coordinate.y == 13 }.map(\.kind).contains(.waterTower))
    }

    func testStarterDistrictOffersSeveralValidGrowthFrontagesOnBothBlocks() {
        let state = CityGameState.newCity(seed: 42)
        let commercialChoices = validCoordinates(for: .commercial, in: state)
        let industrialChoices = validCoordinates(for: .industrial, in: state)

        XCTAssertEqual(commercialChoices, industrialChoices)
        XCTAssertEqual(commercialChoices.count, 46)
        XCTAssertGreaterThanOrEqual(commercialChoices.filter { $0.x < 12 }.count, 8)
        XCTAssertGreaterThanOrEqual(commercialChoices.filter { $0.x > 12 }.count, 8)
        XCTAssertGreaterThanOrEqual(Set(commercialChoices.map(\.y)).count, 4)
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
        XCTAssertEqual(openingAnalytics.projectedBalance, -90.2, accuracy: 0.001)
        XCTAssertGreaterThan(openingAnalytics.operatingRunwayCycles ?? 0, 280)
        XCTAssertTrue(opening.messages.contains {
            $0.title == "A Town at the Crossroads"
                && $0.detail.contains("$90 operating deficit")
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
