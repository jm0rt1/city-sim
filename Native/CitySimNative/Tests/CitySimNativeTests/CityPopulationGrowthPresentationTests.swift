import XCTest
@testable import CitySimNative

final class CityPopulationGrowthPresentationTests: XCTestCase {
    func testSpareHousingRoutesBothPopulationMandatesToMoveInsNotConstruction() throws {
        let state = readyCity()
        let before = try CityStateFingerprinter.fingerprint(state)
        let analytics = CityAnalytics(state: state)
        XCTAssertEqual(analytics.housingCapacity, 1_680)
        XCTAssertEqual(CityTownCharterDecisionSupport.make(analytics: analytics).primaryResponse.command, .inspectorPopulation)
        XCTAssertEqual(CityRegionalCapitalDecisionSupport.make(analytics: analytics).primaryResponse.command, .inspectorPopulation)
        let growth = CityPopulationGrowthPresentation.make(analytics: analytics, speed: .paused)
        XCTAssertEqual(growth.dailyChange, 1)
        XCTAssertEqual(growth.title, "Move-ins +1/day")
        XCTAssertEqual(growth.response.title, "Resume growth")
        XCTAssertEqual(growth.response.command, .togglePause)
        XCTAssertTrue(growth.detail.contains("1,309"))
        XCTAssertEqual(try CityStateFingerprinter.fingerprint(state), before)
    }

    func testActualHousingGapStillOffersConstructionAndCountsOnlyCompletedCapacity() {
        var state = readyCity()
        let residential = state.tiles.indices.filter { state.tiles[$0].kind == .residential }
        for index in residential.dropFirst() { state.tiles[index].constructionProgress = 0.5 }
        let analytics = CityAnalytics(state: state)
        XCTAssertEqual(analytics.housingCapacity, 280)
        XCTAssertEqual(CityTownCharterDecisionSupport.make(analytics: analytics).primaryResponse.command, .buildResidential)
        XCTAssertEqual(CityRegionalCapitalDecisionSupport.make(analytics: analytics).primaryResponse.command, .buildResidential)
        let growth = CityPopulationGrowthPresentation.make(analytics: analytics, speed: .paused)
        XCTAssertEqual(growth.dailyChange, 0)
        XCTAssertEqual(growth.response.command, .buildResidential)
    }

    func testMoveInConstraintsExplainUtilitiesHappinessAndJobsInsteadOfMoreHousing() {
        var state = readyCity()
        state.powerUsed = 900
        state.powerCapacity = 700
        var growth = CityPopulationGrowthPresentation.make(analytics: CityAnalytics(state: state), speed: .paused)
        XCTAssertLessThan(growth.dailyChange, 0)
        XCTAssertEqual(growth.response.command, .inspectorUtilities)
        state = readyCity()
        state.happiness = 45
        growth = CityPopulationGrowthPresentation.make(analytics: CityAnalytics(state: state), speed: .paused)
        XCTAssertEqual(growth.dailyChange, 0)
        XCTAssertEqual(growth.response.command, .inspectorHappiness)
        state.happiness = 31
        XCTAssertLessThan(CitySimulation.projectedDailyPopulationChange(in: state), 0)
        state.powerCapacity = 870
        state.powerUsed = 1_000
        growth = CityPopulationGrowthPresentation.make(analytics: CityAnalytics(state: state), speed: .paused)
        XCTAssertEqual(growth.response.command, .inspectorHappiness, "Stop actual departures before a separate move-in hold")
        state = readyCity()
        for index in state.tiles.indices where [.commercial, .industrial].contains(state.tiles[index].kind) {
            state.tiles[index].kind = .empty
        }
        growth = CityPopulationGrowthPresentation.make(analytics: CityAnalytics(state: state), speed: .paused)
        XCTAssertEqual(growth.dailyChange, 0)
        XCTAssertEqual(growth.response.command, .inspectorEmployment)
        XCTAssertTrue(growth.detail.contains("More homes alone will not restart"))
    }

    func testDailyEstimateKeepsOriginalGrowthRulesAndDoesNotAdvanceState() throws {
        for population in [0, 119, 279, 371, 500, 1_679, 1_680] {
            for happiness in [31.0, 32, 45, 45.1, 70] {
                for use in [100, 880, 1_130, 1_300] {
                    var state = readyCity()
                    state.population = population
                    state.happiness = happiness
                    state.powerCapacity = 1_000
                    state.powerUsed = use
                    let before = try CityStateFingerprinter.fingerprint(state)
                    let capacity = min(CitySimulation.housingCapacity(in: state), max(120, CitySimulation.jobCapacity(in: state) * 2))
                    let coverage = CitySimulation.utilityCoverage(in: state)
                    let expected: Int
                    if population < capacity && coverage > 0.88 && happiness > 45 {
                        expected = min(capacity, population + max(1, Int(Double(population) * (0.0015 + state.demand.residential * 0.0015)))) - population
                    } else if coverage < 0.82 || happiness < 32 {
                        expected = max(0, population - max(1, population / 150)) - population
                    } else { expected = 0 }
                    XCTAssertEqual(CitySimulation.projectedDailyPopulationChange(in: state), expected)
                    XCTAssertEqual(try CityStateFingerprinter.fingerprint(state), before)
                }
            }
        }
    }

    @MainActor
    func testReviewAndResumeAreNonBuildingActionsAndPauseLabelTracksSpeed() {
        let store = CityGameStore(state: readyCity())
        store.speed = .paused
        let before = store.state
        let review = CityTownCharterDecisionSupport.make(analytics: store.analytics).primaryResponse
        StrategyCommandCenterView.perform(review, on: store)
        XCTAssertEqual(store.inspectorSection, .population)
        XCTAssertEqual(store.interactionMode, .inspect)
        XCTAssertNil(store.selectedCoordinate)
        let resume = CityPopulationGrowthPresentation.make(analytics: store.analytics, speed: store.speed)
        StrategyCommandCenterView.perform(resume.response, on: store)
        XCTAssertNotEqual(store.speed, .paused)
        let pause = CityPopulationGrowthPresentation.make(analytics: store.analytics, speed: store.speed)
        XCTAssertEqual(pause.response.title, "Pause growth")
        StrategyCommandCenterView.perform(pause.response, on: store)
        XCTAssertEqual(store.speed, .paused)
        XCTAssertEqual(store.state, before)
        XCTAssertFalse(store.canUndo)
    }

    private func readyCity() -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        state.population = 371
        state.jobs = 259
        state.happiness = 55
        state.powerCapacity = 1_000
        state.waterCapacity = 1_000
        state.powerUsed = 310
        state.waterUsed = 280
        state.taxRate = 0.17
        state.treasury = 20_000
        for index in state.tiles.indices where [.commercial, .industrial].contains(state.tiles[index].kind) {
            state.tiles[index].level = 3
        }
        return state
    }
}
