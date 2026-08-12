import AppKit
import SwiftUI
import XCTest
@testable import CitySimNative

final class CityObjectivePresentationTests: XCTestCase {
    @MainActor
    func testEveryStartingMandateExposesTheGovernanceContract() {
        let store = CityGameStore(state: .newCity(seed: 20260812), startsPaused: true)

        XCTAssertEqual(store.objectivePresentations.map(\.id), ["stabilize", "capacity", "town-charter"])
        for item in store.objectivePresentations {
            XCTAssertFalse(item.currentValue.isEmpty, item.id)
            XCTAssertFalse(item.targetValue.isEmpty, item.id)
            XCTAssertFalse(item.persistence.isEmpty, item.id)
            XCTAssertFalse(item.deadline.isEmpty, item.id)
            XCTAssertFalse(item.reward.isEmpty, item.id)
            XCTAssertFalse(item.passRule.isEmpty, item.id)
            XCTAssertFalse(item.failRule.isEmpty, item.id)
            XCTAssertFalse(item.diagnosticLabel.isEmpty, item.id)
            XCTAssertTrue(item.accessibilitySummary.contains("Current:"), item.id)
            XCTAssertTrue(item.accessibilitySummary.contains("Pass:"), item.id)
        }
    }

    func testTrendComparesCurrentProgressWithThePreviousPulse() {
        let analytics = CityAnalytics(state: .newCity(seed: 7))
        let objective = CityObjective(
            id: "stabilize",
            title: "Balance the Books",
            detail: "Restore operating cashflow",
            progress: 0.6,
            remaining: "Close the gap"
        )

        XCTAssertEqual(
            CityObjectivePresentation.make(
                objective: objective,
                analytics: analytics,
                previousProgress: nil
            ).trend,
            .baseline
        )
        XCTAssertEqual(
            CityObjectivePresentation.make(
                objective: objective,
                analytics: analytics,
                previousProgress: 0.5
            ).trend,
            .improving
        )
        XCTAssertEqual(
            CityObjectivePresentation.make(
                objective: objective,
                analytics: analytics,
                previousProgress: 0.7
            ).trend,
            .slipping
        )
        XCTAssertEqual(
            CityObjectivePresentation.make(
                objective: objective,
                analytics: analytics,
                previousProgress: 0.6
            ).trend,
            .steady
        )
    }

    @MainActor
    func testStrategyDiagnosisRoutesToTheRelevantRecoveryInspector() throws {
        var commercialState = CityGameState.newCity(seed: 11)
        commercialState.progression = CityProgressionState(
            strategy: CityStrategyProgression(
                committedStrategy: .commercialStewardship,
                currentPhase: .recovery,
                nextScheduledTick: commercialState.tick + 16
            )
        )
        let commercial = CityGameStore(state: commercialState, startsPaused: true)
        let commercialObjective = try XCTUnwrap(commercial.objectives.first { $0.id == "strategy" })
        commercial.openObjective(commercialObjective)
        XCTAssertTrue(commercial.showInspector)
        XCTAssertEqual(commercial.inspectorSection, .finances)

        var industrialState = commercialState
        industrialState.progression?.strategy?.committedStrategy = .industrialExpansion
        let industrial = CityGameStore(state: industrialState, startsPaused: true)
        let industrialObjective = try XCTUnwrap(industrial.objectives.first { $0.id == "strategy" })
        industrial.openObjective(industrialObjective)
        XCTAssertTrue(industrial.showInspector)
        XCTAssertEqual(industrial.inspectorSection, .utilities)
    }

    @MainActor
    func testObjectiveRulesMatchDurableCharterAndRegionalProgression() throws {
        var charterState = CityGameState.newCity(seed: 21)
        charterState.progression = CityProgressionState(townCharterQualifyingCycles: 5)
        let charterStore = CityGameStore(state: charterState, startsPaused: true)
        let charter = try XCTUnwrap(
            charterStore.objectivePresentations.first { $0.id == "town-charter" }
        )
        XCTAssertEqual(charter.persistence, "5 of 12 consecutive qualifying days")
        XCTAssertTrue(charter.passRule.contains("500 population"))
        XCTAssertTrue(charter.passRule.contains("2R/1C/1I"))
        XCTAssertTrue(charter.failRule.contains("resets"))

        var regionalState = charterState
        regionalState.progression = CityProgressionState(
            townCharterQualifyingCycles: CitySimulation.townCharterQualificationCycles,
            townCharterAwarded: true,
            strategy: CityStrategyProgression(
                committedStrategy: .industrialExpansion,
                currentPhase: .completed,
                nextScheduledTick: nil,
                recoveryResolution: .industrialGreenBuffer
            ),
            secondAct: CitySecondActProgression(
                phase: .qualification,
                nextScheduledTick: nil,
                qualifyingCycles: 7
            )
        )
        let regionalStore = CityGameStore(state: regionalState, startsPaused: true)
        let regional = try XCTUnwrap(
            regionalStore.objectivePresentations.first { $0.id == "regional-capital" }
        )
        XCTAssertEqual(regional.persistence, "7 of 12 consecutive qualifying days")
        XCTAssertTrue(regional.passRule.contains("525 population"))
        XCTAssertTrue(regional.passRule.contains("20% utility reserve"))
        XCTAssertTrue(regional.reward.contains("Permanent"))
    }

    @MainActor
    func testMayorMandateRendersAtMinimumNativeWindowSize() throws {
        let defaults = try isolatedDefaults()
        defaults.set(true, forKey: CityPlayerPreferenceKey.hasSeenWelcome)
        defaults.set(true, forKey: CityPlayerPreferenceKey.reduceMotion)
        let store = CityGameStore(state: .newCity(seed: 20260812), startsPaused: true)
        store.showObjectives = true
        let size = CGSize(width: 900, height: 600)
        let image = try bitmap(
            of: ZStack {
                Color.black
                ContentView(store: store)
                    .defaultAppStorage(defaults)
            }
            .frame(width: size.width, height: size.height),
            size: size
        )

        XCTAssertEqual(image.size.width, 900, accuracy: 0.5)
        XCTAssertEqual(image.size.height, 600, accuracy: 0.5)
        XCTAssertGreaterThan(try opaquePixelRatio(in: image), 0.95)

        if let path = ProcessInfo.processInfo.environment["CITYSIM_OBJECTIVES_PROOF"] {
            let data = try XCTUnwrap(image.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }

    private func isolatedDefaults() throws -> UserDefaults {
        let suite = "CityObjectivePresentationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        addTeardownBlock {
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        }
        return defaults
    }

    @MainActor
    private func bitmap<Content: View>(of content: Content, size: CGSize) throws -> NSBitmapImageRep {
        let view = NSHostingView(rootView: content)
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.35))
        let representation = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: representation)
        return representation
    }

    private func opaquePixelRatio(in image: NSBitmapImageRep) throws -> Double {
        guard image.pixelsWide > 0, image.pixelsHigh > 0 else { return 0 }
        var opaque = 0
        var sampled = 0
        for y in stride(from: 0, to: image.pixelsHigh, by: 8) {
            for x in stride(from: 0, to: image.pixelsWide, by: 8) {
                sampled += 1
                if let color = image.colorAt(x: x, y: y), color.alphaComponent > 0.01 {
                    opaque += 1
                }
            }
        }
        return Double(opaque) / Double(sampled)
    }
}
