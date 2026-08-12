import XCTest
@testable import CitySimNative

final class NewRegionConfirmationTests: XCTestCase {
    func testPresentationIdentifiesTheExactCityCheckpointAtRisk() {
        var state = CityGameState.newCity(seed: 42)
        state.cityName = "Harbor Point"
        state.tick = 44
        state.population = 512

        XCTAssertEqual(
            NewRegionConfirmationPresentation.make(state: state),
            NewRegionConfirmationPresentation(
                title: "Replace Harbor Point?",
                message: "Harbor Point · Day 12 · 512 residents will be replaced. "
                    + "Save the city first if you want to return to this checkpoint.",
                destructiveActionTitle: "Start New Region",
                cancelActionTitle: "Keep Harbor Point"
            )
        )
    }

    @MainActor
    func testNewRegionCommandPausesAndPreservesTheLiveCityUntilConfirmed() throws {
        var state = CityGameState.newCity(seed: 42)
        state.cityName = "Harbor Point"
        state.tick = 44
        state.population = 512
        let store = CityGameStore(state: state)
        store.setSpeed(.fastest)
        let fingerprint = try CityStateFingerprinter.fingerprint(store.state)

        XCTAssertTrue(store.perform(.newRegion))

        XCTAssertEqual(try CityStateFingerprinter.fingerprint(store.state), fingerprint)
        XCTAssertEqual(store.speed, .paused)
        XCTAssertEqual(
            store.newRegionConfirmation,
            NewRegionConfirmationPresentation.make(state: state)
        )
        XCTAssertFalse(store.canRouteMapCommand(.mapMoveEast))
        XCTAssertFalse(store.canPerform(.saveCity))
        XCTAssertEqual(
            store.disabledReason(for: .saveCity),
            "Choose whether to keep or replace Harbor Point"
        )

        XCTAssertTrue(store.confirmNewRegionReplacement())
        XCTAssertNil(store.newRegionConfirmation)
        XCTAssertEqual(store.state.cityName, "New Arcadia")
        XCTAssertEqual(store.state.formattedDay, "Day 1")
        XCTAssertEqual(store.state.population, 300)
        XCTAssertEqual(store.speed, .paused)
        XCTAssertEqual(store.lastFeedback, "A fresh region is ready")
    }

    @MainActor
    func testCancellingReplacementRestoresTheExactCityAndRunningSpeed() throws {
        var state = CityGameState.newCity(seed: 7)
        state.cityName = "Harbor Point"
        state.tick = 44
        let store = CityGameStore(state: state)
        store.setSpeed(.fastest)
        let fingerprint = try CityStateFingerprinter.fingerprint(store.state)

        XCTAssertTrue(store.perform(.newRegion))
        XCTAssertTrue(store.perform(.cancelInteraction))

        XCTAssertNil(store.newRegionConfirmation)
        XCTAssertEqual(try CityStateFingerprinter.fingerprint(store.state), fingerprint)
        XCTAssertEqual(store.speed, .fastest)
        XCTAssertTrue(store.canRouteMapCommand(.mapMoveEast))
        XCTAssertEqual(store.lastFeedback, "Harbor Point kept · Simulation resumed at 3x")
    }
}
