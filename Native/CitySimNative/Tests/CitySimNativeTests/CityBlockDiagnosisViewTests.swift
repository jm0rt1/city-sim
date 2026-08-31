import AppKit
import SwiftUI
import XCTest
@testable import CitySimNative

final class CityBlockDiagnosisViewTests: XCTestCase {
    @MainActor
    func testCompleteMultiProblemDiagnosisFitsTheInitialNativeDetailsView() {
        let diagnosis = CitySelectedLocationDiagnosis(
            coordinate: GridCoordinate(x: 3, y: 10),
            cause: "Power service is severe at 0%; Water service is severe at 0%; Civic service coverage is weak at 13%: Fire 0%, Police 0%, School 38%",
            consequence: "This block is stable at 56% vitality. Only completed civic sites reachable over connected streets support local value, happiness, and vitality.",
            responses: [
                .init(title: "Add power capacity", command: .buildPowerPlant, explanation: "Add power near this block.", focusesMap: true),
                .init(title: "Build fire station", command: .buildFireStation, explanation: "Add connected fire coverage.", focusesMap: true),
                .init(title: "Show service coverage", command: .overlayServices, explanation: "Compare civic coverage.", focusesMap: true)
            ]
        )
        for compact in [true, false] {
            let width = compact ? BuildToolbarView.compactDetailsWidth : BuildToolbarView.regularDetailsWidth
            let host = NSHostingView(rootView: CityBlockDiagnosisView(diagnosis: diagnosis) { _ in
                XCTFail("Rendering a diagnosis must not perform a remedy")
            }.frame(width: width - 6))
            host.layoutSubtreeIfNeeded()
            let contentHeight = host.fittingSize.height
            let headerAndSpacing: CGFloat = compact ? 59 : 63
            XCTAssertGreaterThan(contentHeight, GameTheme.controlMinimum)
            XCTAssertLessThanOrEqual(
                contentHeight + headerAndSpacing,
                BuildToolbarView.detailsHeight(compact: compact, selectedBlock: true),
                "Complete causes, consequences, and both action controls must fit without scrolling"
            )
        }
    }

    @MainActor
    func testLargerSelectedBlockDetailsDoNotExpandCitywidePanelsOrChangeTheirGrid() {
        XCTAssertEqual(BuildToolbarView.detailsHeight(compact: true, selectedBlock: false), 196)
        XCTAssertEqual(BuildToolbarView.detailsHeight(compact: false, selectedBlock: false), 144)
        XCTAssertEqual(BuildToolbarView.detailsHeight(compact: true, selectedBlock: true), 220)
        XCTAssertEqual(BuildToolbarView.detailsHeight(compact: false, selectedBlock: true), 220)
        XCTAssertEqual(InspectorView.compactColumnCount, 2)
        XCTAssertEqual(InspectorView.regularColumnCount, 4)
    }
}
