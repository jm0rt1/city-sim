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

    func testRegionalQualificationInterruptionAndResumptionStaySignedInTheHUD() {
        let interruption = CityMessage(
            tick: 900,
            severity: .warning,
            title: "Regional Qualification Interrupted",
            detail: "Six qualifying days were lost. Raise happiness to 56%."
        )
        let interrupted = HUDConsequenceFeedbackPresentation.make(from: [interruption])
        XCTAssertEqual(interrupted?.direction, .negative)
        XCTAssertTrue(interrupted?.visualText.contains("Six qualifying days were lost") == true)

        let resumption = CityMessage(
            tick: 904,
            severity: .good,
            title: "Regional Qualification Resumed",
            detail: "Every Regional Capital standard is met again."
        )
        let resumed = HUDConsequenceFeedbackPresentation.make(from: [resumption])
        XCTAssertEqual(resumed?.direction, .positive)
        XCTAssertTrue(resumed?.visualText.hasPrefix("+") == true)
    }

    func testTownCharterInterruptionAndResumptionStaySignedInTheHUD() {
        let interruption = CityMessage(
            tick: 700,
            severity: .warning,
            title: "Town Charter Qualification Interrupted",
            detail: "Five qualifying days were lost. Raise happiness to 52%."
        )
        XCTAssertEqual(
            HUDConsequenceFeedbackPresentation.make(from: [interruption])?.direction,
            .negative
        )

        let resumption = CityMessage(
            tick: 704,
            severity: .good,
            title: "Town Charter Qualification Resumed",
            detail: "Every Town Charter standard is met again."
        )
        XCTAssertEqual(
            HUDConsequenceFeedbackPresentation.make(from: [resumption])?.direction,
            .positive
        )
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
        let defaults = UserDefaults.standard
        let priorWelcome = defaults.object(forKey: "hasSeenCitySimWelcome")
        defaults.set(true, forKey: "hasSeenCitySimWelcome")
        defer {
            if let priorWelcome { defaults.set(priorWelcome, forKey: "hasSeenCitySimWelcome") }
            else { defaults.removeObject(forKey: "hasSeenCitySimWelcome") }
        }

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
                bottom: CGRect(x: 0, y: 600 - (OverlayDiagnosticsPaletteView.compactMaximumHeight + BuildToolbarView.compactOpenMaximumHeight), width: 900, height: OverlayDiagnosticsPaletteView.compactMaximumHeight + BuildToolbarView.compactOpenMaximumHeight)
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
        XCTAssertEqual(OverlayDiagnosticsPaletteView.regularMaximumHeight, 48)
        XCTAssertEqual(compactAfter - compactBefore, 112, accuracy: 0.001)
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

        let regularComposed = try composedCapture(
            size: CGSize(width: 1_280, height: 800),
            selectedDetails: true,
            focusCity: false
        )
        let compactComposed = try composedCapture(
            size: CGSize(width: 900, height: 600),
            selectedDetails: true,
            focusCity: false
        )
        let regularFocus = try composedCapture(
            size: CGSize(width: 1_280, height: 800),
            selectedDetails: true,
            focusCity: true
        )
        let compactFocus = try composedCapture(
            size: CGSize(width: 900, height: 600),
            selectedDetails: true,
            focusCity: true
        )

        XCTAssertEqual(regularComposed.bitmap.size, CGSize(width: 1_280, height: 800))
        XCTAssertEqual(compactComposed.bitmap.size, CGSize(width: 900, height: 600))

        let regularAperture = ContentView.interactiveMapHeight(
            windowHeight: 800,
            chromeFrames: regularComposed.frames
        )
        let compactAperture = ContentView.interactiveMapHeight(
            windowHeight: 600,
            chromeFrames: compactComposed.frames
        )
        let regularFocusAperture = ContentView.interactiveMapHeight(
            windowHeight: 800,
            chromeFrames: regularFocus.frames
        )
        let compactFocusAperture = ContentView.interactiveMapHeight(
            windowHeight: 600,
            chromeFrames: compactFocus.frames
        )
        let previousRegularAperture = 800 - TopHUDView.regularMaximumHeight
            - OverlayDiagnosticsPaletteView.regularMaximumHeight
            - BuildToolbarView.regularOpenMaximumHeight
        let previousCompactAperture = 600 - TopHUDView.compactMaximumHeight
            - OverlayDiagnosticsPaletteView.compactMaximumHeight
            - BuildToolbarView.compactOpenMaximumHeight

        XCTAssertGreaterThan(regularAperture, previousRegularAperture)
        XCTAssertGreaterThan(compactAperture, previousCompactAperture)
        XCTAssertGreaterThanOrEqual(regularAperture / 800, 0.60)
        XCTAssertGreaterThanOrEqual(compactAperture / 600, 0.50)
        XCTAssertGreaterThanOrEqual(regularAperture, regularFocusAperture * 0.60)
        XCTAssertGreaterThanOrEqual(compactAperture, compactFocusAperture * 0.50)
        print(
            "PLAY145_COMPOSED_APERTURE before_regular=\(previousRegularAperture) " +
            "after_regular=\(regularAperture) focus_regular=\(regularFocusAperture) " +
            "before_compact=\(previousCompactAperture) after_compact=\(compactAperture) " +
            "focus_compact=\(compactFocusAperture)"
        )

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

    @MainActor
    private func composedCapture(
        size: CGSize,
        selectedDetails: Bool,
        focusCity: Bool
    ) throws -> (bitmap: NSBitmapImageRep, frames: CityHUDChromeFrames) {
        let store = CityGameStore(state: .newCity(seed: 42))
        store.speed = .paused
        if selectedDetails {
            store.select(GridCoordinate(x: 10, y: 11))
        }
        if focusCity {
            XCTAssertTrue(store.perform(.toggleCityFocus))
        }

        let capture = ChromeFrameCapture()
        let view = NSHostingView(
            rootView: ContentView(store: store) { frames in
                capture.frames = frames
            }
            .frame(width: size.width, height: size.height)
        )
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        view.layoutSubtreeIfNeeded()

        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        XCTAssertFalse(capture.frames.top.isEmpty)
        if focusCity {
            XCTAssertTrue(capture.frames.bottom.isEmpty)
        } else {
            XCTAssertFalse(capture.frames.bottom.isEmpty)
        }
        return (bitmap, capture.frames)
    }
}

@MainActor
private final class ChromeFrameCapture {
    var frames = CityHUDChromeFrames()
}
