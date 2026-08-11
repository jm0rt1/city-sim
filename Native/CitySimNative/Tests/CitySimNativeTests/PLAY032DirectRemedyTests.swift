import AppKit
import SwiftUI
import XCTest
@testable import CitySimNative

final class PLAY032DirectRemedyTests: XCTestCase {
    @MainActor
    func testSevereStormPublishesTruthfulDirectUtilitiesRemedyThroughOneStoreIntent() throws {
        let storm = CityMessage(
            tick: 800,
            severity: .warning,
            title: "Severe Storm",
            detail: "Emergency repairs cost $2,000 and happiness fell 3 points."
        )
        let actions = CityNoticeActionCatalog.actions(for: storm.title)
        let remedy = try XCTUnwrap(actions.first)
        XCTAssertEqual(remedy.title, "Review utilities")
        XCTAssertEqual(remedy.command, .inspectorUtilities)
        XCTAssertFalse(remedy.focusesMap)
        XCTAssertTrue(remedy.explanation.contains("does not reverse an applied cost"))

        var state = CityGameState.newCity(seed: 42)
        state.messages = [storm]
        let store = CityGameStore(state: state)
        let feedback = try XCTUnwrap(HUDConsequenceFeedbackPresentation.make(from: store.state.messages))
        XCTAssertEqual(feedback.message.detail, storm.detail)

        StrategyCommandCenterView.perform(remedy, on: store)

        XCTAssertTrue(store.showInspector)
        XCTAssertEqual(store.inspectorSection, .utilities)
        XCTAssertEqual(store.selectedCoordinate, nil)
    }

    @MainActor
    func testSevereStormRemedyRendersAtDefaultAndCompactHUDBounds() throws {
        var state = CityGameState.newCity(seed: 42)
        state.messages = [CityMessage(
            tick: 800,
            severity: .warning,
            title: "Severe Storm",
            detail: "Emergency repairs cost $2,000 and happiness fell 3 points."
        )]
        let store = CityGameStore(state: state)
        let compactSize = CGSize(width: 884, height: StrategyCommandCenterView.compactMaximumHeight)
        let regularSize = CGSize(width: 1_240, height: StrategyCommandCenterView.regularMaximumHeight)

        let compact = try bitmap(
            of: StrategyCommandCenterView(store: store, compact: true)
                .frame(width: compactSize.width, height: compactSize.height),
            size: compactSize
        )
        let regular = try bitmap(
            of: StrategyCommandCenterView(store: store, compact: false)
                .frame(width: regularSize.width, height: regularSize.height),
            size: regularSize
        )

        XCTAssertEqual(compact.size.width, compactSize.width, accuracy: 0.5)
        XCTAssertEqual(compact.size.height, compactSize.height, accuracy: 0.5)
        XCTAssertEqual(regular.size.width, regularSize.width, accuracy: 0.5)
        XCTAssertEqual(regular.size.height, regularSize.height, accuracy: 0.5)

        if let path = ProcessInfo.processInfo.environment["CITYSIM_PLAY032_COMPACT_PROOF"] {
            let data = try XCTUnwrap(compact.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
        if let path = ProcessInfo.processInfo.environment["CITYSIM_PLAY032_REGULAR_PROOF"] {
            let data = try XCTUnwrap(regular.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
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
