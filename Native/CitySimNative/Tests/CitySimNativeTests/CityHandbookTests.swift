import AppKit
import SwiftUI
import XCTest
@testable import CitySimNative

final class CityHandbookTests: XCTestCase {
    private let presentation = CityHandbookPresentation.standard

    func testStandardInventoryIsDeterministicAndComplete() {
        XCTAssertEqual(
            presentation.sections.map(\.id),
            [
                .gettingStarted,
                .buildAndUndo,
                .diagnoseCity,
                .savesAndRecovery,
                .keyboardControls,
                .accessibility
            ]
        )
        XCTAssertEqual(presentation.sections.map(\.entries.count), [3, 3, 3, 4, 5, 4])
        XCTAssertEqual(Set(presentation.sections.flatMap { $0.entries.map(\.id) }).count, 22)

        let all = presentation.search(query: "")
        XCTAssertEqual(all.sections, presentation.sections)
        XCTAssertEqual(all.entryCount, 22)
        XCTAssertEqual(all.countSummary, "6 sections · 22 items")
    }

    func testSearchMatchesTitlesSummariesKeywordsAndIndividualEntries() throws {
        XCTAssertEqual(presentation.search(query: "Getting Started").sections.map(\.id), [.gettingStarted])
        XCTAssertEqual(presentation.search(query: "first road").sections.map(\.id), [.gettingStarted])
        XCTAssertEqual(presentation.search(query: "cashflow").sections.map(\.id), [.gettingStarted])

        let entryTitle = try XCTUnwrap(presentation.search(query: "Undo Construction").sections.first)
        XCTAssertEqual(entryTitle.id, .buildAndUndo)
        XCTAssertEqual(entryTitle.entries.map(\.id), ["build-undo"])

        let entryDetail = try XCTUnwrap(presentation.search(query: "sanitized diagnostic").sections.first)
        XCTAssertEqual(entryDetail.id, .savesAndRecovery)
        XCTAssertEqual(entryDetail.entries.map(\.id), ["save-support"])

        let entryKeyword = try XCTUnwrap(presentation.search(query: "motor pointer").sections.first)
        XCTAssertEqual(entryKeyword.id, .accessibility)
        XCTAssertEqual(entryKeyword.entries.map(\.id), ["access-keyboard"])

        let photoMode = try XCTUnwrap(presentation.search(query: "photo mode png").sections.first)
        XCTAssertEqual(photoMode.id, .keyboardControls)
        XCTAssertEqual(photoMode.entries.map(\.id), ["keys-photo-mode"])

        XCTAssertEqual(
            presentation.search(query: "  VOICEOVER  ").sections.map(\.id),
            [.accessibility]
        )
    }

    func testSectionFilteringAndNoResultBehaviorAreExplicit() {
        let selected = presentation.search(query: "", sectionID: .diagnoseCity)
        XCTAssertEqual(selected.sections.map(\.id), [.diagnoseCity])
        XCTAssertEqual(selected.entryCount, 3)

        let noResult = presentation.search(query: "quantum ferry timetable")
        XCTAssertTrue(noResult.isEmpty)
        XCTAssertEqual(noResult.sections, [])
        XCTAssertEqual(noResult.countSummary, "No guidance found")
        XCTAssertEqual(CityHandbookSearchResult.noResultTitle, "No handbook matches")
        XCTAssertEqual(
            CityHandbookSearchResult.noResultDetail,
            "Try a command, city problem, save type, or keyboard shortcut."
        )
    }

    func testPlayerGuidanceCoversGrowthDiagnosisAndRecoveryTruth() throws {
        let growth = try section(.gettingStarted)
        XCTAssertTrue(growth.summary.contains("growth loop"))
        XCTAssertTrue(growth.entries.contains { $0.detail.contains("provide power and water") })

        let diagnosis = try section(.diagnoseCity)
        XCTAssertTrue(diagnosis.entries.contains {
            $0.detail.contains("Land Value, Traffic Pressure, Utilities, Happiness, and Pollution")
        })
        XCTAssertTrue(diagnosis.entries.contains { $0.detail.contains("Compare more than one signal") })

        let recovery = try section(.savesAndRecovery)
        XCTAssertTrue(recovery.entries.contains { $0.detail.contains("rotating autosaves") })
        XCTAssertTrue(recovery.entries.contains { $0.detail.contains("authored scenario checkpoints") })
        XCTAssertTrue(recovery.entries.contains { $0.detail.contains("preserved migration copies") })
        XCTAssertTrue(recovery.entries.contains {
            $0.detail.contains("sanitized diagnostic report")
                && $0.detail.contains("original recovery file remains unchanged")
        })
    }

    func testAccessibilitySummaryAndGuidanceStateSupportedAccessPaths() throws {
        XCTAssertEqual(
            presentation.accessibilitySummary,
            "City Handbook. 6 sections covering the growth loop, building and undo, diagnostics, saves and recovery, keyboard controls, and accessibility."
        )
        let accessibility = try section(.accessibility)
        XCTAssertTrue(accessibility.summary.contains("keyboard navigation"))
        XCTAssertTrue(accessibility.summary.contains("VoiceOver-ready descriptions"))
        XCTAssertTrue(accessibility.summary.contains("reduced motion"))
        XCTAssertTrue(accessibility.entries.contains { $0.detail.contains("labels, values, and hints") })
        XCTAssertTrue(accessibility.entries.contains { $0.detail.contains("pair color with text, symbols, or values") })
        XCTAssertTrue(accessibility.entries.contains { $0.detail.contains("Reduce ambient animation") })
    }

    @MainActor
    func testCloseActionIsSharedByViewControls() {
        var closeCount = 0
        let view = CityHandbookView { closeCount += 1 }

        view.close()

        XCTAssertEqual(closeCount, 1)
    }

    @MainActor
    func testHandbookRendersAtCompactAndRegularAcceptanceSizes() throws {
        for size in [CGSize(width: 900, height: 600), CGSize(width: 1_280, height: 800)] {
            let image = try bitmap(
                of: CityHandbookView(closeAction: {})
                    .frame(width: size.width, height: size.height),
                size: size
            )
            XCTAssertEqual(image.size.width, size.width, accuracy: 0.5)
            XCTAssertEqual(image.size.height, size.height, accuracy: 0.5)
            XCTAssertGreaterThan(try opaquePixelRatio(in: image), 0.90)

            if size.width > 1_000,
               let path = ProcessInfo.processInfo.environment["CITYSIM_HANDBOOK_PROOF"] {
                let data = try XCTUnwrap(image.representation(using: .png, properties: [:]))
                try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            }
        }
    }

    private func section(_ id: CityHandbookSectionID) throws -> CityHandbookSection {
        try XCTUnwrap(presentation.sections.first { $0.id == id })
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

    private func opaquePixelRatio(in image: NSBitmapImageRep) throws -> Double {
        guard image.pixelsWide > 0, image.pixelsHigh > 0 else { return 0 }
        var opaque = 0
        let total = image.pixelsWide * image.pixelsHigh
        for y in stride(from: 0, to: image.pixelsHigh, by: 8) {
            for x in stride(from: 0, to: image.pixelsWide, by: 8) {
                if let color = image.colorAt(x: x, y: y), color.alphaComponent > 0.01 {
                    opaque += 1
                }
            }
        }
        let sampledWidth = (image.pixelsWide + 7) / 8
        let sampledHeight = (image.pixelsHigh + 7) / 8
        XCTAssertGreaterThan(total, 0)
        return Double(opaque) / Double(sampledWidth * sampledHeight)
    }
}
