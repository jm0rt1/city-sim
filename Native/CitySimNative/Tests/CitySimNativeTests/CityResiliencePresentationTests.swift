import Foundation
import XCTest
@testable import CitySimNative

final class CityResiliencePresentationTests: XCTestCase {
    func testIncidentScheduleExposesTheNextReviewAndFirstGuaranteedStorm() {
        var state = CityGameState.newCity(seed: 42)
        state.population = 500
        state.tick = 639

        XCTAssertEqual(CitySimulation.nextIncidentReviewTick(in: state), 640)
        XCTAssertEqual(CitySimulation.firstGuaranteedStormReviewTick(in: state), 800)

        state.tick = 640
        XCTAssertEqual(CitySimulation.nextIncidentReviewTick(in: state), 800)
        XCTAssertEqual(CitySimulation.firstGuaranteedStormReviewTick(in: state), 800)

        state.tick = 800
        XCTAssertEqual(CitySimulation.nextIncidentReviewTick(in: state), 960)
        XCTAssertEqual(CitySimulation.firstGuaranteedStormReviewTick(in: state), 960)
    }

    func testGrowthWatchNamesThresholdAndRoutesAnUnderpreparedCityToUtilities() {
        var state = CityGameState.newCity(seed: 43)
        state.population = 420
        state.powerUsed = 285
        state.waterUsed = 256

        let presentation = CityResiliencePresentation.make(
            analytics: CityAnalytics(state: state)
        )

        XCTAssertEqual(presentation.phase, .growthWatch)
        XCTAssertEqual(presentation.status, "GROWTH WATCH")
        XCTAssertEqual(presentation.timingLabel, "80 residents until watch begins")
        XCTAssertTrue(presentation.reserveLabel.contains("5% / 15% required"))
        XCTAssertTrue([CityCommandID.buildPowerPlant, .buildWaterTower].contains(
            presentation.primaryResponse.command
        ))
        XCTAssertTrue(presentation.primaryResponse.focusesMap)
        XCTAssertTrue(presentation.accessibilitySummary.contains("Next action:"))
    }

    func testPreparedForecastNamesReviewAndGuaranteedStormDays() {
        var state = CityGameState.newCity(seed: 44)
        state.population = 500
        state.tick = 639

        let presentation = CityResiliencePresentation.make(
            analytics: CityAnalytics(state: state)
        )

        XCTAssertEqual(presentation.phase, .ready)
        XCTAssertEqual(presentation.status, "READY")
        XCTAssertEqual(
            presentation.timingLabel,
            "Next review Day 161 · first storm by Day 201"
        )
        XCTAssertEqual(presentation.exposureLabel, "Up to 3 completed homes exposed")
        XCTAssertEqual(presentation.primaryResponse.command, .buildPark)
    }

    func testActiveRecoveryDistinguishesBlockedAndRepairingStates() {
        var state = CityGameState.newCity(seed: 45)
        state.population = 600
        state.tick = 804
        state.stormRecovery = CityStormRecoveryState(
            latestEventTick: 800,
            latestEventSeed: 99,
            targets: [
                CityStormRecoveryTarget(
                    coordinate: GridCoordinate(x: 10, y: 11),
                    remainingConditionDamage: 0.24
                )
            ],
            disposition: .active
        )
        state.powerUsed = 285
        state.waterUsed = 258

        var presentation = CityResiliencePresentation.make(
            analytics: CityAnalytics(state: state)
        )
        XCTAssertEqual(presentation.phase, .recoveryBlocked)
        XCTAssertEqual(presentation.status, "RECOVERY BLOCKED")
        XCTAssertTrue(presentation.recoveryLabel.contains("24% average damage remaining"))

        state.powerUsed = 240
        state.waterUsed = 215
        presentation = CityResiliencePresentation.make(
            analytics: CityAnalytics(state: state)
        )
        XCTAssertEqual(presentation.phase, .recovering)
        XCTAssertEqual(presentation.status, "RECOVERING")
        XCTAssertEqual(presentation.primaryResponse.command, .buildPark)
    }

    func testIncidentFreeSandboxReportsNoScheduleOrFalseUrgency() {
        var state = CityGameState.newCity(seed: 46)
        state.population = 700
        state.sandboxRules = CitySandboxRules(
            economy: .standard,
            incidentsEnabled: false,
            unlimitedFunds: false
        )

        let presentation = CityResiliencePresentation.make(
            analytics: CityAnalytics(state: state)
        )

        XCTAssertNil(CitySimulation.nextIncidentReviewTick(in: state))
        XCTAssertNil(CitySimulation.firstGuaranteedStormReviewTick(in: state))
        XCTAssertEqual(presentation.phase, .incidentsDisabled)
        XCTAssertEqual(presentation.status, "INCIDENTS OFF")
        XCTAssertEqual(presentation.primaryResponse.command, .inspectorOverview)
    }

    func testStormProtectionIsBoundedAndUsesCompletedAuthoritativeLots() {
        var state = CityGameState.newCity(seed: 47)
        state.tiles.indices.forEach { index in
            if state.tiles[index].kind == .residential {
                state.tiles[index].constructionProgress = 1
            }
        }

        let baseline = CitySimulation.stormProtection(in: state)
        XCTAssertEqual(baseline.exposedResidentialLots, 3)
        XCTAssertEqual(baseline.parkCount, 1)
        XCTAssertEqual(baseline.serviceCount, 0)
        XCTAssertGreaterThanOrEqual(baseline.estimatedConditionDamage, 0.08)

        let unfinished = state.tiles.firstIndex { $0.kind == .residential }!
        state.tiles[unfinished].constructionProgress = 0.5
        XCTAssertEqual(
            CitySimulation.stormProtection(in: state).exposedResidentialLots,
            3,
            "Exposure remains capped at the same three-home simulation rule"
        )
    }

    func testHandbookFindsTheSameStormRulesAndShortcut() throws {
        let result = CityHandbookPresentation.standard.search(query: "storm reserve")
        let entry = try XCTUnwrap(
            result.sections.flatMap(\.entries).first { $0.id == "diagnose-resilience" }
        )

        XCTAssertEqual(entry.shortcut, "⌥0")
        XCTAssertTrue(entry.detail.contains("15% reserve"))
        XCTAssertTrue(entry.detail.contains("first guaranteed ordinary storm"))
    }
}
