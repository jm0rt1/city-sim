import XCTest
@testable import CitySimNative

final class CitySessionReplacementConfirmationTests: XCTestCase {
    func testPresentationsIdentifyTheExactCityCheckpointAndReplacementAction() throws {
        var state = CityGameState.newCity(seed: 42)
        state.cityName = "Harbor Point"
        state.tick = 44
        state.population = 512
        var saved = CityGameState.newCity(seed: 99)
        saved.cityName = "Saved Harbor"
        saved.tick = 8
        saved.population = 304

        XCTAssertEqual(
            CitySessionReplacementConfirmationPresentation.make(
                state: state,
                action: .newRegion
            ),
            CitySessionReplacementConfirmationPresentation(
                action: .newRegion,
                title: "Choose another mode for Harbor Point?",
                message: "The current checkpoint — Harbor Point · Day 12 · 512 residents — stays unchanged while you browse. "
                    + "Starting a guided city, scenario, or sandbox replaces this session; "
                    + "Benchmark runs separately without changing it. Save first if you want a return checkpoint.",
                destructiveActionTitle: "Open Mode Chooser",
                cancelActionTitle: "Keep Harbor Point"
            )
        )
        let autosave = CitySessionReplacementConfirmationPresentation.make(
            state: state,
            action: .loadQuicksave,
            loadResult: SaveGameLoadResult(
                state: saved,
                schemaVersion: 1,
                fingerprint: try CityStateFingerprinter.fingerprint(saved),
                source: .autosave
            )
        )
        XCTAssertTrue(autosave.message.contains("latest verified rotating autosave"))
        let branch = CitySessionReplacementConfirmationPresentation.make(
            state: state,
            action: .loadQuicksave,
            loadResult: SaveGameLoadResult(
                state: saved,
                schemaVersion: 1,
                fingerprint: try CityStateFingerprinter.fingerprint(saved),
                source: .branch,
                branchName: "Before Freight"
            )
        )
        XCTAssertTrue(branch.message.contains("named timeline branch “Before Freight”"))
        let scenario = CitySessionReplacementConfirmationPresentation.make(
            state: state,
            action: .loadQuicksave,
            loadResult: SaveGameLoadResult(
                state: saved,
                schemaVersion: 1,
                fingerprint: try CityStateFingerprinter.fingerprint(saved),
                source: .scenario,
                scenarioCheckpointID: "town-charter",
                scenarioCheckpointTitle: "Town Charter Secured"
            )
        )
        XCTAssertTrue(scenario.message.contains("authored scenario checkpoint “Town Charter Secured”"))
        XCTAssertEqual(
            CitySessionReplacementConfirmationPresentation.make(
                state: state,
                action: .loadQuicksave,
                loadResult: SaveGameLoadResult(
                    state: saved,
                    schemaVersion: 1,
                    fingerprint: try CityStateFingerprinter.fingerprint(saved),
                    source: .backup
                )
            ),
            CitySessionReplacementConfirmationPresentation(
                action: .loadQuicksave,
                title: "Load Saved Harbor?",
                message: "Saved Harbor · Day 3 · 304 residents will replace "
                    + "Harbor Point · Day 12 · 512 residents. Save Harbor Point first if you "
                    + "want to return to its current checkpoint. This checkpoint was recovered "
                    + "from the last known-good backup.",
                destructiveActionTitle: "Load Saved Harbor",
                cancelActionTitle: "Keep Harbor Point"
            )
        )
    }

    @MainActor
    func testNewRegionCommandPausesAndPreservesTheProgressedCityUntilConfirmed() throws {
        var state = CityGameState.newCity(seed: 42)
        state.cityName = "Harbor Point"
        state.tick = 44
        state.population = 512
        let store = CityGameStore(state: state)
        store.setSpeed(.fastest)
        store.overlay = .pollution
        store.showObjectives = true
        let fingerprint = try CityStateFingerprinter.fingerprint(store.state)

        XCTAssertTrue(store.perform(.newRegion))

        XCTAssertEqual(try CityStateFingerprinter.fingerprint(store.state), fingerprint)
        XCTAssertEqual(store.speed, .paused)
        XCTAssertEqual(store.sessionReplacementConfirmation?.action, .newRegion)
        XCTAssertFalse(store.canRouteMapCommand(.mapMoveEast))
        XCTAssertFalse(store.canPerform(.saveCity))
        XCTAssertEqual(
            store.disabledReason(for: .saveCity),
            "Choose whether to open the mode chooser or keep Harbor Point"
        )

        XCTAssertTrue(store.confirmSessionReplacement())
        XCTAssertNil(store.sessionReplacementConfirmation)
        XCTAssertEqual(try CityStateFingerprinter.fingerprint(store.state), fingerprint)
        XCTAssertEqual(store.commandPolicy, .blocked(.newRegionSetup))
        XCTAssertNotNil(store.newRegionSetup)
        XCTAssertEqual(store.speed, .paused)
        store.updateNewRegionExperience(.openSandbox)
        store.updateNewRegionCityName("  Alder Bay  ")
        store.updateNewRegionSeed("987654")
        store.updateNewRegionStartingResources(.generous)
        XCTAssertTrue(store.createNewRegion())
        XCTAssertEqual(store.state.cityName, "Alder Bay")
        XCTAssertEqual(store.state.seed, 987654)
        XCTAssertEqual(store.state.treasury, 60_000)
        XCTAssertEqual(store.state.sandboxRules, .standard)
        XCTAssertEqual(store.state.formattedDay, "Day 1")
        XCTAssertEqual(store.state.population, 300)
        XCTAssertEqual(store.commandPolicy, .enabled)
        XCTAssertEqual(store.overlay, .none)
        XCTAssertFalse(store.showObjectives)
        XCTAssertEqual(
            store.lastFeedback,
            "Sandbox ready · Alder Bay · Seed 987654 · Standard economy · Incidents on · Budget active"
        )
    }

    @MainActor
    func testLoadCommandCanKeepOrReplaceAProgressedCityWithoutAdvancingIt() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-session-replacement-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)

        var saved = CityGameState.newCity(seed: 99)
        saved.cityName = "Saved Harbor"
        for _ in 0..<8 { CitySimulation.step(&saved) }
        try service.save(saved)

        var current = CityGameState.newCity(seed: 42)
        current.cityName = "Harbor Point"
        current.tick = 44
        current.population = 512
        let store = CityGameStore(state: current, saveService: service)
        store.setSpeed(.fastest)
        let fingerprint = try CityStateFingerprinter.fingerprint(current)

        XCTAssertTrue(store.perform(.loadCity))
        XCTAssertEqual(store.commandPolicy, .blocked(.checkpointLibrary))
        XCTAssertNil(store.sessionReplacementConfirmation)
        try store.selectNewestCheckpointForTesting()
        XCTAssertEqual(store.sessionReplacementConfirmation?.action, .loadQuicksave)
        XCTAssertEqual(store.sessionReplacementConfirmation?.title, "Load Saved Harbor?")
        XCTAssertTrue(
            store.sessionReplacementConfirmation?.message.contains("Saved Harbor · Day 3") == true
        )
        XCTAssertEqual(try CityStateFingerprinter.fingerprint(store.state), fingerprint)
        XCTAssertEqual(store.speed, .paused)

        XCTAssertTrue(store.perform(.cancelInteraction))
        XCTAssertNil(store.sessionReplacementConfirmation)
        XCTAssertEqual(try CityStateFingerprinter.fingerprint(store.state), fingerprint)
        XCTAssertEqual(store.speed, .fastest)
        XCTAssertEqual(store.lastFeedback, "Harbor Point kept · Simulation resumed at 3x")

        XCTAssertTrue(store.perform(.loadCity))
        try store.selectNewestCheckpointForTesting()
        XCTAssertTrue(store.confirmSessionReplacement())
        XCTAssertEqual(store.state, saved)
        XCTAssertEqual(store.speed, .paused)
        XCTAssertEqual(
            store.lastFeedback,
            CityPersistenceFeedbackPresentation.loaded(
                saved,
                recoveredFromBackup: false
            ).message
        )
    }

    @MainActor
    func testPristineCitySkipsReplacementConfirmation() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-pristine-replacement-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        var saved = CityGameState.newCity(seed: 99)
        CitySimulation.step(&saved)
        try service.save(saved)

        let loading = CityGameStore(state: .newCity(seed: 42), saveService: service)
        XCTAssertTrue(loading.perform(.loadCity))
        try loading.selectNewestCheckpointForTesting()
        XCTAssertNil(loading.sessionReplacementConfirmation)
        XCTAssertEqual(loading.state, saved)

        let identical = CityGameStore(state: saved, saveService: service)
        XCTAssertTrue(identical.perform(.loadCity))
        try identical.selectNewestCheckpointForTesting()
        XCTAssertNil(identical.sessionReplacementConfirmation)
        XCTAssertEqual(identical.state, saved)
        XCTAssertEqual(identical.speed, .paused)

        let starting = CityGameStore(state: .newCity(seed: 42))
        XCTAssertTrue(starting.perform(.newRegion))
        XCTAssertNil(starting.sessionReplacementConfirmation)
        XCTAssertEqual(starting.commandPolicy, .blocked(.newRegionSetup))
        XCTAssertNotNil(starting.newRegionSetup)
        XCTAssertEqual(starting.state, .newCity(seed: 42))
    }
}
