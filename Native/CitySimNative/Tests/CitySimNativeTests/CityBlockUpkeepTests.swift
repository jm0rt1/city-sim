import XCTest
@testable import CitySimNative

final class CityBlockUpkeepTests: XCTestCase {
    func testSiteCostsReconcileEveryFundingAndEconomyWithoutStateMutation() {
        for economy in CitySandboxEconomy.allCases {
            for road in CityRoadMaintenancePolicy.allCases {
                for civic in CityCivicServiceFundingPolicy.allCases {
                    var state = emptyCity()
                    for (index, kind) in BuildingKind.allCases.enumerated() {
                        put(kind, x: index, level: 2, in: &state)
                    }
                    put(.powerPlant, x: 12, in: &state)
                    put(.waterTower, x: 13, in: &state)
                    put(.school, x: 14, progress: 0.5, in: &state)
                    state.sandboxRules = CitySandboxRules(economy: economy, incidentsEnabled: true, unlimitedFunds: false)
                    state.roadMaintenancePolicy = road
                    state.civicServiceFundingPolicy = civic
                    state.treasury = -6_000
                    let before = state
                    let sites = state.tiles.reduce(0) { $0 + CityBlockUpkeepPresentation.make(for: $1, in: state).amount }
                    let debt = 36 * economy.upkeepMultiplier
                    XCTAssertEqual(sites + debt, CitySimulation.projectedUpkeep(in: state), accuracy: 0.000_001)
                    XCTAssertEqual(state, before)
                }
            }
        }
    }

    func testInspectorAmountsIncludeLevelFundingAndSandboxEconomy() {
        var state = emptyCity()
        let home = put(.residential, x: 1, in: &state)
        XCTAssertEqual(CityBlockUpkeepPresentation.make(for: home, in: state).amount, 7.2, accuracy: 0.000_001)
        XCTAssertTrue(CityBlockUpkeepPresentation.make(for: home, in: state).value.contains("7.20"))
        let road = put(.road, x: 2, level: 2, in: &state)
        state.roadMaintenancePolicy = .preventive
        let roadCost = CityBlockUpkeepPresentation.make(for: road, in: state)
        XCTAssertEqual(roadCost.amount, 10.8, accuracy: 0.000_001)
        XCTAssertTrue(roadCost.accessibilitySummary.contains("Preventive road funding"))
        let school = put(.school, x: 3, level: 2, in: &state)
        state.civicServiceFundingPolicy = .expanded
        let schoolCost = CityBlockUpkeepPresentation.make(for: school, in: state)
        XCTAssertEqual(schoolCost.amount, 504, accuracy: 0.000_001)
        XCTAssertTrue(schoolCost.accessibilitySummary.contains("Expanded service funding"))
        state.sandboxRules = CitySandboxRules(economy: .relaxed, incidentsEnabled: true, unlimitedFunds: true)
        XCTAssertEqual(CityBlockUpkeepPresentation.make(for: school, in: state).amount, 428.4, accuracy: 0.000_001,
                       "Unlimited funds must not erase the operating model")
    }

    func testUtilityDiscountIsSharedOnlyAmongCompletedSameKindSites() {
        var state = emptyCity()
        let primary = put(.powerPlant, x: 1, level: 2, in: &state)
        let reserve = put(.powerPlant, x: 2, in: &state)
        let unfinished = put(.powerPlant, x: 3, progress: 0.5, in: &state)
        let water = put(.waterTower, x: 4, in: &state)
        let primaryCost = CityBlockUpkeepPresentation.make(for: primary, in: state)
        let reserveCost = CityBlockUpkeepPresentation.make(for: reserve, in: state)
        XCTAssertEqual(primaryCost.amount, 320.625, accuracy: 0.000_001)
        XCTAssertEqual(reserveCost.amount, 149.625, accuracy: 0.000_001)
        XCTAssertEqual(primaryCost.label, "Upkeep share")
        XCTAssertEqual(primaryCost.note, "Shared reserve discount")
        XCTAssertTrue(primaryCost.accessibilitySummary.contains("2 completed power plant sites"))
        XCTAssertTrue(primaryCost.accessibilitySummary.contains("not demolition savings"))
        XCTAssertEqual(CityBlockUpkeepPresentation.make(for: unfinished, in: state).amount, 0)
        XCTAssertEqual(CityBlockUpkeepPresentation.make(for: water, in: state).amount, 126)
        XCTAssertNil(CityBlockUpkeepPresentation.make(for: water, in: state).note)
    }

    func testConstructionAndEmptyBlocksDoNotClaimAnActiveCharge() {
        var state = emptyCity()
        let construction = put(.school, x: 1, progress: 0.99, in: &state)
        let cost = CityBlockUpkeepPresentation.make(for: construction, in: state)
        XCTAssertEqual(cost.amount, 0)
        XCTAssertEqual(cost.note, "Starts when operational")
        XCTAssertTrue(cost.accessibilitySummary.contains("no recurring upkeep"))
        let empty = put(.empty, x: 2, in: &state)
        XCTAssertEqual(CityBlockUpkeepPresentation.make(for: empty, in: state).amount, 0)
    }

    private func emptyCity() -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        for index in state.tiles.indices {
            state.tiles[index] = CityTile(coordinate: state.tiles[index].coordinate, kind: .empty)
        }
        return state
    }

    @discardableResult
    private func put(_ kind: BuildingKind, x: Int, level: Int = 1, progress: Double = 1, in state: inout CityGameState) -> CityTile {
        let coordinate = GridCoordinate(x: x, y: 5)
        let tile = CityTile(coordinate: coordinate, kind: kind, level: level)
        state.updateTile(at: coordinate) {
            $0 = tile
            $0.constructionProgress = progress
        }
        return state.tiles.first { $0.coordinate == coordinate }!
    }
}
