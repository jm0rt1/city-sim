import AppKit
import SwiftUI
import XCTest
@testable import CitySimNative

final class HUDConsequenceFeedbackTests: XCTestCase {
    func testMaterialConsequenceIsOneSignedAccessibleCueFromLatestMessage() {
        let storm = CityMessage(
            tick: 800,
            severity: .warning,
            title: "Severe Storm",
            detail: "Emergency repairs cost $2,000 and happiness fell 3 points."
        )
        let olderNoise = CityMessage(
            tick: 799,
            severity: .information,
            title: "Routine Tick",
            detail: "No material change."
        )

        let feedback = HUDConsequenceFeedbackPresentation.make(from: [storm, olderNoise])

        XCTAssertEqual(feedback?.direction, .negative)
        XCTAssertEqual(
            feedback?.visualText,
            "− Severe Storm · Emergency repairs cost $2,000 and happiness fell 3 points."
        )
        XCTAssertEqual(
            feedback?.accessibilityValue,
            "− Severe Storm. Emergency repairs cost $2,000 and happiness fell 3 points."
        )
        XCTAssertNil(HUDConsequenceFeedbackPresentation.make(from: [olderNoise, storm]))
    }

    func testRecoveryKeepsPositiveSignedMeaningAndUsesFullAuthoritativeDetail() {
        let recovery = CityMessage(
            tick: 812,
            severity: .good,
            title: "Storm Recovery Complete",
            detail: "Two residential lots cleared their recorded storm damage."
        )

        let feedback = HUDConsequenceFeedbackPresentation.make(from: [recovery])

        XCTAssertEqual(feedback?.direction, .positive)
        XCTAssertTrue(feedback?.visualText.hasPrefix("+") == true)
        XCTAssertTrue(feedback?.visualText.contains(recovery.detail) == true)
        XCTAssertTrue(feedback?.accessibilityValue.contains(recovery.detail) == true)
    }

    func testFeedbackPreservesCurrentStrategyAccessibilityAndHUDBounds() {
        XCTAssertEqual(TopHUDView.compactMaximumHeight, 104)
        XCTAssertEqual(TopHUDView.regularMaximumHeight, 108)
        XCTAssertEqual(StrategyCommandCenterView.compactMaximumHeight, 48)
        XCTAssertEqual(StrategyCommandCenterView.regularMaximumHeight, 52)
        XCTAssertEqual(GameTheme.controlMinimum, 44)

        let presentation = CityStrategyHUDPresentation(
            eyebrow: "CITY PRIORITY",
            title: "Prepare for the load surge",
            status: "DECISION · 4 DAYS",
            summary: "Diagnose utilities before the consequence.",
            tone: .active,
            diagnostic: nil,
            actions: []
        )
        XCTAssertEqual(
            presentation.accessibilityValue,
            "DECISION · 4 DAYS. Diagnose utilities before the consequence."
        )
    }

    @MainActor
    func testMapFirstComposedViewKeepsMapApertureAtCompactAndRegularSizes() throws {
        XCTAssertEqual(
            ContentView.contextualGuidancePresentation(
                showObjectives: true,
                showInspector: false,
                hasActivity: true
            ),
            .objectives,
            "Objectives take priority over activity so only one guidance layer is visible"
        )
        XCTAssertEqual(
            ContentView.contextualGuidancePresentation(
                showObjectives: false,
                showInspector: false,
                hasActivity: true
            ),
            .activity
        )
        XCTAssertEqual(
            ContentView.contextualGuidancePresentation(
                showObjectives: true,
                showInspector: true,
                hasActivity: true
            ),
            .hidden,
            "Open command-center details are the sole contextual layer"
        )

        let compactBefore = ContentView.interactiveMapHeight(
            windowHeight: 600,
            chromeFrames: CityHUDChromeFrames(
                top: CGRect(x: 0, y: 0, width: 900, height: TopHUDView.compactMaximumHeight),
                bottom: CGRect(x: 0, y: 600 - (70 + BuildToolbarView.compactClosedMaximumHeight), width: 900, height: 70 + BuildToolbarView.compactClosedMaximumHeight)
            )
        )
        let compactAfter = ContentView.interactiveMapHeight(
            windowHeight: 600,
            chromeFrames: CityHUDChromeFrames(
                top: CGRect(x: 0, y: 0, width: 900, height: TopHUDView.compactMaximumHeight),
                bottom: CGRect(x: 0, y: 600 - (OverlayDiagnosticsPaletteView.compactMaximumHeight + BuildToolbarView.compactClosedMaximumHeight), width: 900, height: OverlayDiagnosticsPaletteView.compactMaximumHeight + BuildToolbarView.compactClosedMaximumHeight)
            )
        )
        XCTAssertEqual(OverlayDiagnosticsPaletteView.compactMaximumHeight, 48)
        XCTAssertEqual(compactAfter - compactBefore, 22, accuracy: 0.001)
        XCTAssertGreaterThan(compactAfter, compactBefore)

        let store = CityGameStore(state: .newCity(seed: 42))
        let compactSize = CGSize(width: 900, height: OverlayDiagnosticsPaletteView.compactMaximumHeight)
        let regularSize = CGSize(width: 1_240, height: OverlayDiagnosticsPaletteView.regularMaximumHeight)
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
        XCTAssertEqual(compact.size, compactSize)
        XCTAssertEqual(regular.size, regularSize)

        if let directory = ProcessInfo.processInfo.environment["CITYSIM_PLAY115_PROOF_DIR"] {
            let output = URL(fileURLWithPath: directory, isDirectory: true)
            let compactData = try XCTUnwrap(compact.representation(using: .png, properties: [:]))
            let regularData = try XCTUnwrap(regular.representation(using: .png, properties: [:]))
            try compactData.write(to: output.appendingPathComponent("compact-map-layers.png"), options: .atomic)
            try regularData.write(to: output.appendingPathComponent("regular-map-layers.png"), options: .atomic)
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
