import XCTest
@testable import CitySimNative

final class CityGrowthCapacityPresentationTests: XCTestCase {
    func testStarterCityNamesWaterAsTheFirstResilienceBottleneck() {
        let presentation = CityGrowthCapacityPresentation.make(
            analytics: CityAnalytics(state: .newCity(seed: 42))
        )

        XCTAssertEqual(presentation.phase, .prepare)
        XCTAssertEqual(presentation.constraint, .water)
        XCTAssertEqual(presentation.targetPopulation, 400)
        XCTAssertEqual(presentation.supportedPopulation, 310)
        XCTAssertEqual(presentation.headroom, 10)
        XCTAssertEqual(presentation.response.command, .buildWaterTower)
        XCTAssertEqual(presentation.decisionTitle, "Water limits +100")
        XCTAssertTrue(presentation.detail.contains("79 more water capacity"))
        XCTAssertTrue(presentation.accessibilitySummary.contains("Next action: Build Water Tower"))
    }

    func testForecastSelectsHousingAndJobsFromAuthoritativeCapacity() throws {
        var housingState = baseState(population: 250)
        retainOneZone(.residential, level: 1, in: &housingState)
        retainOneZone(.commercial, level: 3, in: &housingState)
        housingState.powerCapacity = 1_000
        housingState.waterCapacity = 1_000

        let housing = CityGrowthCapacityPresentation.make(
            analytics: CityAnalytics(state: housingState)
        )
        XCTAssertEqual(housing.constraint, .housing)
        XCTAssertEqual(housing.supportedPopulation, 280)
        XCTAssertEqual(housing.response.command, .buildResidential)
        XCTAssertTrue(housing.detail.contains("70 more housing capacity"))

        var jobsState = baseState(population: 100)
        retainOneZone(.residential, level: 1, in: &jobsState)
        retainOneZone(.commercial, level: 1, in: &jobsState)
        removeZone(.industrial, from: &jobsState)
        jobsState.powerCapacity = 1_000
        jobsState.waterCapacity = 1_000

        let jobs = CityGrowthCapacityPresentation.make(
            analytics: CityAnalytics(state: jobsState)
        )
        XCTAssertEqual(jobs.constraint, .jobs)
        XCTAssertEqual(jobs.supportedPopulation, 160)
        XCTAssertEqual(jobs.response.command, .buildCommercial)
        XCTAssertTrue(jobs.detail.contains("20 more jobs"))
    }

    func testForecastPreservesSimulationEmploymentFloorAndCommittedGrowthRoute() {
        var floorState = baseState(population: 50)
        removeZone(.commercial, from: &floorState)
        removeZone(.industrial, from: &floorState)
        floorState.powerCapacity = 1_000
        floorState.waterCapacity = 1_000

        let floorForecast = CityGrowthCapacityPresentation.make(
            analytics: CityAnalytics(state: floorState)
        )
        XCTAssertEqual(floorForecast.constraint, .jobs)
        XCTAssertEqual(floorForecast.supportedPopulation, 120)
        XCTAssertEqual(floorForecast.phase, .prepare)
        XCTAssertEqual(floorForecast.headroom, 70)

        var committedState = baseState(population: 100)
        retainOneZone(.residential, level: 1, in: &committedState)
        removeZone(.commercial, from: &committedState)
        removeZone(.industrial, from: &committedState)
        committedState.powerCapacity = 1_000
        committedState.waterCapacity = 1_000
        committedState.progression = CityProgressionState(
            strategy: CityStrategyProgression(
                committedStrategy: .industrialExpansion,
                currentPhase: .opportunity,
                nextScheduledTick: committedState.tick + 16
            )
        )

        let committed = CityGrowthCapacityPresentation.make(
            analytics: CityAnalytics(state: committedState)
        )
        XCTAssertEqual(committed.constraint, .jobs)
        XCTAssertEqual(committed.response.command, .buildIndustrial)
    }

    func testForecastDistinguishesPowerPreparationCurrentWaterShortfallAndReadyState() {
        var powerState = baseState(population: 300)
        boostJobCapacity(in: &powerState)
        powerState.powerCapacity = 340
        powerState.waterCapacity = 1_000

        let power = CityGrowthCapacityPresentation.make(
            analytics: CityAnalytics(state: powerState)
        )
        XCTAssertEqual(power.phase, .prepare)
        XCTAssertEqual(power.constraint, .power)
        XCTAssertEqual(power.response.command, .buildPowerPlant)
        XCTAssertTrue(power.detail.contains("46 more power capacity"))

        var shortfallState = baseState(population: 300)
        boostJobCapacity(in: &shortfallState)
        shortfallState.powerCapacity = 1_000
        shortfallState.waterCapacity = 200

        let shortfall = CityGrowthCapacityPresentation.make(
            analytics: CityAnalytics(state: shortfallState)
        )
        XCTAssertEqual(shortfall.phase, .currentShortfall)
        XCTAssertEqual(shortfall.constraint, .water)
        XCTAssertEqual(shortfall.status, "CURRENT SHORTFALL")
        XCTAssertEqual(shortfall.decisionTitle, "Water short now")
        XCTAssertEqual(shortfall.headroom, 0)

        var readyState = baseState(population: 300)
        boostJobCapacity(in: &readyState)
        readyState.powerCapacity = 1_000
        readyState.waterCapacity = 1_000

        let ready = CityGrowthCapacityPresentation.make(
            analytics: CityAnalytics(state: readyState)
        )
        XCTAssertEqual(ready.phase, .ready)
        XCTAssertNil(ready.constraint)
        XCTAssertEqual(ready.status, "READY")
        XCTAssertEqual(ready.decisionTitle, "Ready for +100")
        XCTAssertEqual(ready.response.command, .inspectorDemand)
        XCTAssertFalse(ready.response.focusesMap)
    }

    @MainActor
    func testForecastActionUsesTheExistingMapFocusedCommandAndPauses() {
        let store = CityGameStore(state: .newCity(seed: 44), startsPaused: false)
        store.setSpeed(.fast)
        let presentation = CityGrowthCapacityPresentation.make(analytics: store.analytics)

        StrategyCommandCenterView.perform(presentation.response, on: store)

        XCTAssertEqual(store.interactionMode, .build(.waterTower))
        XCTAssertEqual(store.speed, .paused)
        XCTAssertGreaterThan(store.mapFocusRequestGeneration, 0)
    }

    private func baseState(population: Int) -> CityGameState {
        var state = CityGameState.newCity(seed: 99)
        state.population = population
        state.powerUsed = Int(Double(population) * 0.82)
        state.waterUsed = Int(Double(population) * 0.74)
        return state
    }

    private func removeZone(_ kind: BuildingKind, from state: inout CityGameState) {
        for index in state.tiles.indices where state.tiles[index].kind == kind {
            state.tiles[index].kind = .empty
        }
    }

    private func retainOneZone(
        _ kind: BuildingKind,
        level: Int,
        in state: inout CityGameState
    ) {
        var retained = false
        for index in state.tiles.indices where state.tiles[index].kind == kind {
            if retained {
                state.tiles[index].kind = .empty
            } else {
                state.tiles[index].level = level
                retained = true
            }
        }
    }

    private func boostJobCapacity(in state: inout CityGameState) {
        for index in state.tiles.indices where state.tiles[index].kind == .commercial {
            state.tiles[index].level = 2
        }
        for index in state.tiles.indices where state.tiles[index].kind == .industrial {
            state.tiles[index].level = 2
        }
    }
}
