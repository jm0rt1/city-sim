import AppKit
import SwiftUI
import Vision
import XCTest
@testable import CitySimNative

final class CityNoticeJournalTests: XCTestCase {
    private func summary(_ title: String, tick: Int = 10, count: Int = 1) -> CityMessageSummary {
        .init(message: .init(tick: tick, severity: .warning, title: title, detail: "Full notice text"), count: count)
    }

    func testSelectionFollowsNoticeGroupWithoutIncomingMessagesStealingFocus() {
        let first = summary("First")
        let selected = summary("Selected")
        XCTAssertEqual(CityNoticeJournalSelection.index(for: nil, in: [first, selected]), 0)
        XCTAssertEqual(CityNoticeJournalSelection.index(for: selected.id, in: [first, selected]), 1)
        let repeated = summary("Selected", tick: 40, count: 2)
        XCTAssertEqual(CityNoticeJournalSelection.index(for: selected.id, in: [summary("New"), first, repeated]), 2)
        XCTAssertEqual(CityNoticeJournalSelection.index(for: "missing", in: [first]), 0)
        XCTAssertNil(CityNoticeJournalSelection.index(for: selected.id, in: []))
    }

    func testDismissalChoosesNextThenPreviousAndHandlesLastNotice() {
        let items = [summary("First"), summary("Second"), summary("Third")]
        XCTAssertEqual(CityNoticeJournalSelection.afterDismissal(at: 0, in: items), items[1].id)
        XCTAssertEqual(CityNoticeJournalSelection.afterDismissal(at: 1, in: items), items[2].id)
        XCTAssertEqual(CityNoticeJournalSelection.afterDismissal(at: 2, in: items), items[1].id)
        XCTAssertNil(CityNoticeJournalSelection.afterDismissal(at: 0, in: [items[0]]))
    }

    @MainActor
    func testDismissalRemovesOnlyTheSelectedGroupAndReadingDoesNotMutateCity() {
        var state = CityGameState.newCity(seed: 42)
        let old = summary("Selected").message
        let new = summary("Selected", tick: 30).message
        let otherSeverity = CityMessage(tick: 20, severity: .good, title: "Selected", detail: "Other event")
        state.messages = [new, summary("Other").message, old, otherSeverity]
        let store = CityGameStore(state: state)
        let before = store.state
        let selected = store.messageSummaries[0]
        XCTAssertEqual(selected.count, 2)
        XCTAssertEqual(CityNoticeJournalSelection.index(for: selected.id, in: store.messageSummaries), 0)
        XCTAssertEqual(store.state, before)
        store.dismissMessageSummary(selected)
        var expected = before
        expected.messages = [before.messages[1], otherSeverity]
        XCTAssertEqual(store.state, expected)
        XCTAssertFalse(store.canUndo)
    }

    @MainActor
    func testReaderShowsFullRegionalInstructionAndFooterWithinBothPanelBudgets() throws {
        for compact in [true, false] {
            var state = CityGameState.newCity(seed: 42)
            state.messages = [.init(tick: 976, severity: .critical, title: "Regional Retail Pressure",
                detail: "Competitors pulled spending away, costing $4,500 and 5 happiness. 2 developed storefront parcels now show the damage. Build a third park to create a regional public-realm draw.")]
            let store = CityGameStore(state: state)
            let before = store.state
            let width = compact ? BuildToolbarView.compactDetailsWidth : BuildToolbarView.regularDetailsWidth
            let host = NSHostingView(rootView: CityNoticeJournalView(store: store, compact: compact)
                .preferredColorScheme(.dark).frame(width: width - 6))
            host.layoutSubtreeIfNeeded()
            let height = host.fittingSize.height
            XCTAssertLessThanOrEqual(height + (compact ? 59 : 63),
                BuildToolbarView.detailsHeight(compact: compact, selectedBlock: false, journal: true))
            XCTAssertEqual(BuildToolbarView.detailsHeight(compact: compact, selectedBlock: false, journal: true), compact ? 196 : 216)
            host.frame = CGRect(x: 0, y: 0, width: width - 6, height: height)
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            try VNImageRequestHandler(cgImage: XCTUnwrap(bitmap.cgImage)).perform([request])
            let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ").lowercased()
            for required in ["regional retail pressure", "third park", "public-realm draw", "related data", "actions", "dismiss"] {
                XCTAssertTrue(text.contains(required), "\(compact): Missing \(required): \(text)")
            }
            XCTAssertEqual(store.state, before)
            XCTAssertFalse(store.canUndo)
        }
    }
}
