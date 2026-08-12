import Foundation
import XCTest
@testable import CitySimNative

final class CitySandboxRulesTests: XCTestCase {
    func testEconomyRuleChangesRevenueAndUpkeepInBothDirections() {
        var relaxed = CityGameState.newCity(seed: 91)
        var standard = relaxed
        var demanding = relaxed
        relaxed.sandboxRules = CitySandboxRules(
            economy: .relaxed,
            incidentsEnabled: true,
            unlimitedFunds: false
        )
        standard.sandboxRules = .standard
        demanding.sandboxRules = CitySandboxRules(
            economy: .demanding,
            incidentsEnabled: true,
            unlimitedFunds: false
        )

        XCTAssertGreaterThan(
            CitySimulation.projectedRevenue(in: relaxed),
            CitySimulation.projectedRevenue(in: standard)
        )
        XCTAssertLessThan(
            CitySimulation.projectedUpkeep(in: relaxed),
            CitySimulation.projectedUpkeep(in: standard)
        )
        XCTAssertLessThan(
            CitySimulation.projectedRevenue(in: demanding),
            CitySimulation.projectedRevenue(in: standard)
        )
        XCTAssertGreaterThan(
            CitySimulation.projectedUpkeep(in: demanding),
            CitySimulation.projectedUpkeep(in: standard)
        )
        XCTAssertGreaterThan(
            CitySimulation.projectedBalance(in: relaxed),
            CitySimulation.projectedBalance(in: standard)
        )
        XCTAssertGreaterThan(
            CitySimulation.projectedBalance(in: standard),
            CitySimulation.projectedBalance(in: demanding)
        )
    }

    func testDisabledIncidentsPreventTheGuaranteedFirstStorm() {
        var incidentsOn = CityGameState.newCity(seed: 92)
        incidentsOn.progression = nil
        // Leave headroom for the daily population adjustment that precedes incident creation.
        incidentsOn.population = 600
        incidentsOn.tick = 796
        incidentsOn.sandboxRules = .standard

        var incidentsOff = incidentsOn
        incidentsOff.sandboxRules?.incidentsEnabled = false

        for _ in 0..<4 {
            CitySimulation.step(&incidentsOn)
            CitySimulation.step(&incidentsOff)
        }

        XCTAssertNotNil(incidentsOn.stormRecovery)
        XCTAssertTrue(incidentsOn.messages.contains { $0.title == "Severe Storm" })
        XCTAssertNil(incidentsOff.stormRecovery)
        XCTAssertFalse(incidentsOff.messages.contains { $0.title == "Severe Storm" })
    }

    func testUnlimitedFundsWaiveConstructionDemolitionAndOperatingSpending() {
        var state = CityGameState.newCity(seed: 93)
        state.progression = nil
        state.treasury = 0
        state.sandboxRules = CitySandboxRules(
            economy: .demanding,
            incidentsEnabled: true,
            unlimitedFunds: true
        )
        let coordinate = GridCoordinate(x: 4, y: 8)

        guard case .success = CitySimulation.validateBuild(.residential, at: coordinate, in: state) else {
            return XCTFail("Unlimited funds should bypass the treasury requirement")
        }
        guard case .success = CitySimulation.build(.residential, at: coordinate, in: &state) else {
            return XCTFail("Unlimited-funds construction should succeed")
        }
        XCTAssertEqual(state.treasury, 0)
        XCTAssertTrue(CitySimulation.demolish(at: coordinate, in: &state))
        XCTAssertEqual(state.treasury, 0)

        for _ in 0..<8 { CitySimulation.step(&state) }

        XCTAssertEqual(state.treasury, 0)
        XCTAssertEqual(state.status, .playing)
        XCTAssertFalse(state.messages.contains { $0.title == "Budget Gap" })
    }

    func testSandboxRulesRoundTripWithSaveState() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-sandbox-rules-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        var draft = CityNewRegionDraft.initial(seed: 20260812)
        draft.experience = .openSandbox
        draft.cityName = "Rule Harbor"
        draft.sandboxEconomy = .relaxed
        draft.incidentsEnabled = false
        draft.unlimitedFunds = true
        let state = try XCTUnwrap(draft.configuration?.makeState())

        let write = try service.save(state)
        let load = try service.load()

        XCTAssertEqual(load.state, state)
        XCTAssertEqual(load.state.sandboxRules, CitySandboxRules(
            economy: .relaxed,
            incidentsEnabled: false,
            unlimitedFunds: true
        ))
        XCTAssertEqual(load.fingerprint, write.fingerprint)
    }

    func testSandboxRemainsCampaignFreeAfterDailySimulationBoundary() throws {
        var draft = CityNewRegionDraft.initial(seed: 94)
        draft.experience = .openSandbox
        draft.cityName = "Open Horizon"
        var state = try XCTUnwrap(draft.configuration?.makeState())

        for _ in 0..<4 { CitySimulation.step(&state) }

        XCTAssertNil(state.progression)
        XCTAssertFalse(state.messages.contains { message in
            ["Choose a Growth Engine", "Town Charter Standards"].contains(message.title)
        })
    }

    @MainActor
    func testSetupCallbacksCommitExactRulesAndStartPaused() throws {
        let store = CityGameStore(state: .newCity(seed: 7))
        store.openNewRegionSetup(suggestedSeed: 8080)
        store.updateNewRegionExperience(.openSandbox)
        store.updateNewRegionCityName("Freebuild Bay")
        store.updateNewRegionSandboxEconomy(.demanding)
        store.updateNewRegionSandboxIncidents(false)
        store.updateNewRegionSandboxUnlimitedFunds(true)

        XCTAssertTrue(store.createNewRegion())
        XCTAssertEqual(store.state.cityName, "Freebuild Bay")
        XCTAssertEqual(store.state.sandboxRules, CitySandboxRules(
            economy: .demanding,
            incidentsEnabled: false,
            unlimitedFunds: true
        ))
        XCTAssertNil(store.state.progression)
        XCTAssertEqual(store.speed, .paused)
        XCTAssertTrue(store.lastFeedback?.contains("Demanding economy") == true)
        XCTAssertTrue(store.lastFeedback?.contains("Unlimited funds") == true)
    }
}
