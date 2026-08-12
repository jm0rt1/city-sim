import XCTest
@testable import CitySimNative

final class CityHandbookIntegrationTests: XCTestCase {
    func testHandbookCommandHasDedicatedGlobalHelpShortcut() {
        let descriptor = CityCommandCatalog.descriptor(for: .openHandbook)

        XCTAssertEqual(descriptor.title, "City Handbook")
        XCTAssertEqual(descriptor.category, .panels)
        XCTAssertEqual(descriptor.route, .store)
        XCTAssertEqual(descriptor.shortcut?.key, "/")
        XCTAssertEqual(descriptor.shortcut?.modifiers, [.command, .shift])
        XCTAssertEqual(descriptor.shortcut?.display, "⇧⌘?")
        XCTAssertEqual(
            CityCommandCatalog.matchingCommand(
                key: "/",
                modifiers: [.command, .shift],
                scope: .global
            ),
            .openHandbook
        )
    }

    @MainActor
    func testHandbookIsAvailableWithoutMutatingPausedCityOrBlockingJourney() {
        for policy in [
            CityCommandPolicy.enabled,
            .blocked(.welcome),
            .blocked(.startupResume),
            .blocked(.checkpointLibrary),
            .blocked(.branchNaming),
        ] {
            let store = CityGameStore(
                state: .newCity(seed: 1_201),
                commandPolicy: policy,
                startsPaused: true
            )
            let state = store.state
            let speed = store.speed

            XCTAssertTrue(store.perform(.openHandbook), String(describing: policy))
            XCTAssertTrue(store.showCityHandbook)
            XCTAssertFalse(store.showCommandGuide)
            XCTAssertEqual(store.state, state)
            XCTAssertEqual(store.speed, speed)
            XCTAssertEqual(store.commandPolicy, policy)

            store.showCityHandbook = false
        }
    }

    @MainActor
    func testOpeningHelpSurfacesIsExclusiveAndEscapeClosesHandbookFirst() {
        let store = CityGameStore(state: .newCity(seed: 1_202))

        XCTAssertTrue(store.perform(.openCommandGuide))
        XCTAssertTrue(store.showCommandGuide)
        XCTAssertTrue(store.perform(.openHandbook))
        XCTAssertTrue(store.showCityHandbook)
        XCTAssertFalse(store.showCommandGuide)

        XCTAssertTrue(store.perform(.cancelInteraction))
        XCTAssertFalse(store.showCityHandbook)
        XCTAssertFalse(store.showCommandGuide)

        XCTAssertTrue(store.perform(.openHandbook))
        XCTAssertTrue(store.perform(.openCommandGuide))
        XCTAssertFalse(store.showCityHandbook)
        XCTAssertTrue(store.showCommandGuide)
    }

    @MainActor
    func testHandbookRemainsAvailableAfterTerminalOutcomeAndReplacementPrompt() {
        var terminal = CityGameState.newCity(seed: 1_203)
        terminal.status = .won
        let terminalStore = CityGameStore(state: terminal)
        XCTAssertTrue(terminalStore.perform(.openHandbook))
        XCTAssertTrue(terminalStore.showCityHandbook)

        var progressed = CityGameState.newCity(seed: 1_204)
        progressed.tick = 4
        let replacementStore = CityGameStore(state: progressed)
        XCTAssertTrue(replacementStore.perform(.newRegion))
        XCTAssertNotNil(replacementStore.sessionReplacementConfirmation)
        XCTAssertTrue(replacementStore.perform(.openHandbook))
        XCTAssertTrue(replacementStore.showCityHandbook)
        XCTAssertNotNil(replacementStore.sessionReplacementConfirmation)
    }
}
