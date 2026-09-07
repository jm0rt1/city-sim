import XCTest
@testable import CitySimNative

final class CityStrategyPreparedResponseTests: XCTestCase {
    func testTaxReadinessIsImmediateReversibleAndDoesNotLockTheResult() throws {
        var state = city(.commercialStewardship)
        XCTAssertNil(prepared(state))
        state.taxRate = 0.09
        let before = try CityStateFingerprinter.fingerprint(state)
        let ready = try XCTUnwrap(prepared(state))
        XCTAssertEqual(ready.resolution, .commercialTaxRelief)
        XCTAssertEqual(ready.title, "Tax relief ready")
        XCTAssertTrue(ready.detail.contains("Keep tax at 9% or less"))
        XCTAssertTrue(ready.detail.contains("not locked in yet"))
        XCTAssertTrue(ready.detail.contains("Operations still forecast"))
        XCTAssertEqual(CityAnalytics(state: state).strategyObjective?.title, ready.title)
        XCTAssertFalse(try XCTUnwrap(CityAnalytics(state: state).strategyObjective).remaining.contains("build a second park"))
        XCTAssertEqual(try CityStateFingerprinter.fingerprint(state), before)
        XCTAssertNil(state.progression?.strategy?.recoveryResolution)
        state.taxRate = 0.10
        XCTAssertNil(prepared(state))
        XCTAssertEqual(CityAnalytics(state: state).strategyObjective?.title, "Protect Main Street")
    }

    func testPublicSpaceRequiresCompletedParksAndRevokesWhenOneIsRemoved() throws {
        for strategy in [CityStrategy.commercialStewardship, .industrialExpansion] {
            var state = city(strategy)
            let coordinate = GridCoordinate(x: 0, y: 0)
            state.updateTile(at: coordinate) { $0.kind = .park; $0.constructionProgress = 0.75 }
            XCTAssertNil(prepared(state), "Unfinished parks are not a prepared response")
            state.updateTile(at: coordinate) { $0.constructionProgress = 1 }
            XCTAssertEqual(prepared(state)?.resolution, strategy == .commercialStewardship
                ? .commercialPublicRealmInvestment : .industrialGreenBuffer)
            state.updateTile(at: coordinate) { $0.kind = .empty }
            XCTAssertNil(prepared(state))
        }
    }

    func testFreightNeedsBothCompletedUtilityTypesAndUsesSimulationPriority() {
        var state = city(.industrialExpansion)
        state.updateTile(at: GridCoordinate(x: 0, y: 0)) { $0.kind = .powerPlant }
        XCTAssertNil(prepared(state))
        state.updateTile(at: GridCoordinate(x: 1, y: 0)) { $0.kind = .waterTower; $0.constructionProgress = 0.5 }
        XCTAssertNil(prepared(state))
        state.updateTile(at: GridCoordinate(x: 1, y: 0)) { $0.constructionProgress = 1 }
        state.updateTile(at: GridCoordinate(x: 2, y: 0)) { $0.kind = .park }
        XCTAssertEqual(prepared(state)?.resolution, .industrialUtilityExpansion)
        state.updateTile(at: GridCoordinate(x: 0, y: 0)) { $0.kind = .empty }
        XCTAssertEqual(prepared(state)?.resolution, .industrialGreenBuffer)
    }

    func testScheduledSimulationAloneLocksPreparedResponseAndSaveRoundTripIsExact() throws {
        var state = city(.commercialStewardship)
        state.taxRate = 0.09
        state.progression?.strategy?.currentPhase = .setback
        state.progression?.strategy?.nextScheduledTick = 4
        let data = try JSONEncoder().encode(state)
        let restored = try JSONDecoder().decode(CityGameState.self, from: data)
        XCTAssertEqual(prepared(restored), prepared(state))
        XCTAssertEqual(restored, state)
        let expected = try XCTUnwrap(prepared(state)).resolution
        for _ in 0..<4 { CitySimulation.step(&state) }
        XCTAssertEqual(state.progression?.strategy?.recoveryResolution, expected)
        XCTAssertNil(prepared(state), "Recorded results retain the existing recovery presentation")
    }

    @MainActor
    func testReadyActionUsesExistingPauseIntentAndLeavesCityUnchanged() throws {
        var state = city(.commercialStewardship)
        state.taxRate = 0.09
        let store = CityGameStore(state: state, startsPaused: true)
        let ready = CityStrategyHUDPresentation.make(state: state)
        let resume = try XCTUnwrap(ready.diagnostic)
        XCTAssertEqual(resume.title, "Resume to review")
        XCTAssertEqual(resume.command, .togglePause)
        XCTAssertEqual(ready.actions.map(\.command), [.inspectorFinances])
        XCTAssertTrue(ready.accessibilityValue.contains("not locked in yet"))
        StrategyCommandCenterView.perform(resume, on: store)
        XCTAssertNotEqual(store.speed, .paused)
        let running = CityStrategyHUDPresentation.make(state: store.state, speed: store.speed)
        XCTAssertEqual(running.diagnostic?.title, "Pause to inspect")
        StrategyCommandCenterView.perform(try XCTUnwrap(running.diagnostic), on: store)
        XCTAssertEqual(store.speed, .paused)
        XCTAssertEqual(store.state, state)
    }

    func testReadinessDoesNotReplaceCompletedRegionalOrSandboxGuidance() {
        var state = city(.commercialStewardship)
        state.taxRate = 0.09
        for phase in [CityStrategyPhase.opportunity, .complication, .setback, .recovery] {
            state.progression?.strategy?.currentPhase = phase
            XCTAssertNotNil(prepared(state))
        }
        state.progression?.strategy?.currentPhase = .completed
        XCTAssertNil(prepared(state))
        state.progression?.strategy?.currentPhase = .setback
        state.progression?.secondAct = CitySecondActProgression(phase: .mandate, nextScheduledTick: 16)
        XCTAssertNil(prepared(state))
        state.progression?.secondAct = nil
        state.sandboxRules = CitySandboxRules(economy: .demanding, incidentsEnabled: true, unlimitedFunds: true)
        XCTAssertNil(prepared(state))
    }

    private func prepared(_ state: CityGameState) -> CityStrategyPreparedResponse? {
        CityStrategyPreparedResponse.make(analytics: CityAnalytics(state: state))
    }

    private func city(_ strategy: CityStrategy) -> CityGameState {
        var state = CityGameState.newCity(seed: 27)
        state.progression?.strategy = CityStrategyProgression(
            committedStrategy: strategy, currentPhase: .complication, nextScheduledTick: 16
        )
        return state
    }
}
