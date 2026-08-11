import AppKit
import SwiftUI
import XCTest
@testable import CitySimNative

final class PLAY036SearchRemedyTests: XCTestCase {
    @MainActor
    func testWarningSearchesRouteOnceToTaxPolicyAndKeepDisabledReasonsTruthful() throws {
        let queries = ["tax", "budget", "storefront"]
        for query in queries {
            let results = CityCommandCatalog.matchingDescriptors(query: query)
                .filter { $0.id == .inspectorFinances }
            XCTAssertEqual(results.count, 1, query)
            XCTAssertEqual(results[0].title, "Open Tax Policy and Finances")
        }

        let available = CityGameStore(state: .newCity(seed: 42))
        available.showCommandGuide = true
        let command = try XCTUnwrap(
            CityCommandCatalog.matchingDescriptors(query: "storefront").first?.id
        )
        XCTAssertTrue(available.canPerform(command))
        XCTAssertNil(available.disabledReason(for: command))
        XCTAssertTrue(available.performFromCommandGuide(command))
        XCTAssertFalse(available.showCommandGuide)
        XCTAssertTrue(available.showInspector)
        XCTAssertEqual(available.inspectorSection, .finances)
        XCTAssertFalse(available.performFromCommandGuide(command), "The same result cannot activate twice after closing the guide")

        let blocked = CityGameStore(
            state: .newCity(seed: 42),
            commandPolicy: .blocked(.welcome)
        )
        blocked.showCommandGuide = true
        XCTAssertFalse(blocked.canPerform(command))
        XCTAssertEqual(
            blocked.disabledReason(for: command),
            "Finish Welcome to New Arcadia to use city commands"
        )
        XCTAssertFalse(blocked.performFromCommandGuide(command))
        XCTAssertTrue(blocked.showCommandGuide)
        XCTAssertFalse(blocked.showInspector)
    }

    @MainActor
    func testEscapeRestoresMapFocusAndGuideRendersAtUsableBounds() throws {
        let store = CityGameStore(state: .newCity(seed: 42))
        store.showCommandGuide = true
        let focusBefore = store.mapFocusRequestGeneration
        XCTAssertTrue(store.perform(.cancelInteraction))
        XCTAssertFalse(store.showCommandGuide)
        XCTAssertEqual(store.mapFocusRequestGeneration, focusBefore + 1)

        let compactSize = CGSize(width: 620, height: 480)
        let regularSize = CGSize(width: 760, height: 560)
        let compact = try bitmap(
            of: CommandGuideView(store: store).frame(width: compactSize.width, height: compactSize.height),
            size: compactSize
        )
        let regular = try bitmap(
            of: CommandGuideView(store: store).frame(width: regularSize.width, height: regularSize.height),
            size: regularSize
        )

        XCTAssertEqual(compact.size.width, compactSize.width, accuracy: 0.5)
        XCTAssertEqual(compact.size.height, compactSize.height, accuracy: 0.5)
        XCTAssertEqual(regular.size.width, regularSize.width, accuracy: 0.5)
        XCTAssertEqual(regular.size.height, regularSize.height, accuracy: 0.5)
        XCTAssertTrue(ContentView.isCompactLayout(CGSize(width: 900, height: 600)))

        if let path = ProcessInfo.processInfo.environment["CITYSIM_PLAY036_COMPACT_PROOF"] {
            let data = try XCTUnwrap(compact.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
        if let path = ProcessInfo.processInfo.environment["CITYSIM_PLAY036_REGULAR_PROOF"] {
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
