import AppKit
import SwiftUI
import XCTest
@testable import CitySimNative

final class OverlayDiagnosticsPaletteTests: XCTestCase {
    @MainActor
    func testPaletteRoutesEveryLayerAndPublishesHonestNormalizedMetadata() {
        let store = CityGameStore(state: .newCity(seed: 42))

        for overlay in DataOverlay.allCases {
            XCTAssertTrue(store.perform(CityCommandCatalog.id(for: overlay)))
            XCTAssertEqual(store.overlay, overlay)
        }

        let traffic = OverlayDiagnosticsPalettePresentation.make(
            overlay: .traffic,
            consequence: nil,
            tick: 12
        )
        XCTAssertEqual(traffic.title, "Traffic pressure")
        XCTAssertEqual(traffic.value, "No data")
        XCTAssertEqual(traffic.scale, "0–100")
        XCTAssertEqual(traffic.applicability, "No data · roads only")
        XCTAssertEqual(traffic.source, "Spatial consequences")
        XCTAssertEqual(traffic.freshness, "fresh at tick 12")
        XCTAssertTrue(traffic.accessibilityValue.contains("Scale 0–100"))
        XCTAssertTrue(traffic.accessibilityValue.contains("Click a place to open details"))
    }

    @MainActor
    func testPaletteRendersWithinRegularAndExactCompactBounds() throws {
        let store = CityGameStore(state: .newCity(seed: 42))
        let compactSize = CGSize(width: 884, height: OverlayDiagnosticsPaletteView.compactMaximumHeight)
        let regularSize = CGSize(width: 1_120, height: OverlayDiagnosticsPaletteView.regularMaximumHeight)

        let compact = try bitmap(
            of: OverlayDiagnosticsPaletteView(store: store, compact: true)
                .frame(width: compactSize.width, height: compactSize.height),
            size: compactSize
        )
        let regular = try bitmap(
            of: OverlayDiagnosticsPaletteView(store: store, compact: false)
                .frame(width: regularSize.width, height: regularSize.height),
            size: regularSize
        )

        XCTAssertEqual(compact.size.width, compactSize.width, accuracy: 0.5)
        XCTAssertEqual(compact.size.height, compactSize.height, accuracy: 0.5)
        XCTAssertEqual(regular.size.width, regularSize.width, accuracy: 0.5)
        XCTAssertEqual(regular.size.height, regularSize.height, accuracy: 0.5)
        XCTAssertLessThanOrEqual(OverlayDiagnosticsPaletteView.compactMaximumHeight, 70)

        if let path = ProcessInfo.processInfo.environment["CITYSIM_PLAY087_COMPACT_PROOF"] {
            let data = try XCTUnwrap(compact.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
        if let path = ProcessInfo.processInfo.environment["CITYSIM_PLAY087_REGULAR_PROOF"] {
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
