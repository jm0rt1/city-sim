import AppKit
import SwiftUI
import XCTest
@testable import CitySimNative

final class CityNewRegionSetupTests: XCTestCase {
    func testGuidedAndSandboxConfigurationsCreateDeterministicDistinctStarts() throws {
        let guided = try XCTUnwrap(
            CityNewRegionDraft.initial(seed: 42).configuration
        )
        XCTAssertEqual(guided.experience, .guidedFoundations)
        XCTAssertEqual(guided.cityName, "New Arcadia")
        XCTAssertEqual(guided.startingResources, .balanced)
        XCTAssertEqual(guided.makeState(), CityGameState.newCity(seed: 42))

        var sandboxDraft = CityNewRegionDraft.initial(seed: 42)
        sandboxDraft.experience = .openSandbox
        sandboxDraft.cityName = "  Cedar Shore  "
        sandboxDraft.seedText = "20260812"
        sandboxDraft.startingResources = .lean
        let sandbox = try XCTUnwrap(sandboxDraft.configuration)
        let first = sandbox.makeState()
        let second = sandbox.makeState()

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.cityName, "Cedar Shore")
        XCTAssertEqual(first.seed, 20260812)
        XCTAssertEqual(first.treasury, 20_000)
        XCTAssertEqual(first.messages.first?.title, "Open Sandbox Ready")
        XCTAssertTrue(first.messages.first?.detail.contains("optional milestones") == true)
        XCTAssertNotEqual(first, guided.makeState())
    }

    func testSandboxValidationRejectsBlankLongAndNonNumericInputs() {
        var draft = CityNewRegionDraft.initial(seed: 42)
        draft.experience = .openSandbox

        draft.cityName = "   "
        XCTAssertEqual(draft.validationMessage, "Enter a city name.")
        XCTAssertNil(draft.configuration)

        draft.cityName = String(repeating: "A", count: 41)
        XCTAssertEqual(draft.validationMessage, "City names can use at most 40 characters.")
        XCTAssertNil(draft.configuration)

        draft.cityName = "Harbor Light"
        draft.seedText = "not-a-seed"
        XCTAssertTrue(draft.validationMessage?.contains("whole-number seed") == true)
        XCTAssertNil(draft.configuration)

        draft.seedText = "0"
        XCTAssertNil(draft.configuration)
        draft.seedText = "18446744073709551615"
        XCTAssertNotNil(draft.configuration)
    }

    func testModePresentationExplainsPlayerConsequencesBeforeCommitment() {
        let presentation = CityNewRegionSetupPresentation.standard

        XCTAssertEqual(
            CityNewRegionExperience.allCases,
            [.guidedFoundations, .authoredScenario, .openSandbox]
        )
        XCTAssertTrue(presentation.title.contains("Next City"))
        XCTAssertTrue(presentation.guidedHighlights.contains {
            $0.contains("Town Charter and Regional Capital")
        })
        XCTAssertTrue(presentation.sandboxHighlights.contains {
            $0.contains("reproducible seed")
        })
        XCTAssertTrue(presentation.sandboxHighlights.contains {
            $0.contains("milestones are optional")
        })
        let scenario = CityAuthoredScenarioCatalog.harborRecovery
        XCTAssertTrue(scenario.briefing.contains("harbor town"))
        XCTAssertTrue(scenario.objective.contains("Day 41"))
        XCTAssertEqual(scenario.targetTiers.map(\.medal), [.bronze, .silver, .gold])
    }

    @MainActor
    func testSetupPausesWithoutReplacingAndCancelRestoresTheCurrentCity() throws {
        var current = CityGameState.newCity(seed: 77)
        current.cityName = "Harbor Point"
        current.tick = 20
        let store = CityGameStore(state: current)
        store.setSpeed(.fastest)
        let fingerprint = try CityStateFingerprinter.fingerprint(current)

        store.openNewRegionSetup(suggestedSeed: 1234)

        XCTAssertEqual(store.commandPolicy, .blocked(.newRegionSetup))
        XCTAssertEqual(store.speed, .paused)
        XCTAssertEqual(store.newRegionDraft.seedText, "1234")
        XCTAssertEqual(try CityStateFingerprinter.fingerprint(store.state), fingerprint)
        XCTAssertFalse(store.canRouteMapCommand(.mapMoveEast))

        XCTAssertTrue(store.perform(.cancelInteraction))
        XCTAssertNil(store.newRegionSetup)
        XCTAssertEqual(store.commandPolicy, .enabled)
        XCTAssertEqual(store.speed, .fastest)
        XCTAssertEqual(try CityStateFingerprinter.fingerprint(store.state), fingerprint)
        XCTAssertEqual(store.lastFeedback, "Harbor Point kept · New region setup canceled")
    }

    @MainActor
    func testSandboxSetupRendersAtCompactAndDefaultWindowSizes() throws {
        var draft = CityNewRegionDraft.initial(seed: 20260812)
        draft.experience = .openSandbox
        draft.cityName = "Cedar Shore"
        draft.startingResources = .generous

        for size in [CGSize(width: 900, height: 600), CGSize(width: 1_280, height: 800)] {
            let image = try bitmap(
                of: NewRegionSetupView(
                    presentation: .standard,
                    draft: draft,
                    updateExperience: { _ in },
                    updateCityName: { _ in },
                    updateSeed: { _ in },
                    updateStartingResources: { _ in },
                    createAction: {},
                    cancelAction: {}
                )
                .frame(width: size.width, height: size.height),
                size: size
            )
            XCTAssertEqual(image.size.width, size.width, accuracy: 0.5)
            XCTAssertEqual(image.size.height, size.height, accuracy: 0.5)
            if size.width > 1_000,
               let path = ProcessInfo.processInfo.environment["CITYSIM_NEW_REGION_SETUP_PROOF"] {
                let data = try XCTUnwrap(image.representation(using: .png, properties: [:]))
                try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            }
        }
    }

    @MainActor
    private func bitmap<Content: View>(of content: Content, size: CGSize) throws -> NSBitmapImageRep {
        let view = NSHostingView(rootView: content)
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        let representation = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: representation)
        return representation
    }
}
