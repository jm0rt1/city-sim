import XCTest
@testable import CitySimNative

final class WelcomeViewTests: XCTestCase {
    private let presentation = WelcomePresentation.firstRun

    func testFirstRunGoalNamesTheTownCharterAsA500ResidentMilestoneNotTheDestination() {
        XCTAssertTrue(presentation.objective.contains("current operating gap"))
        XCTAssertTrue(presentation.objective.contains("Town Charter at 500 residents"))
        XCTAssertTrue(presentation.objective.contains("then keep growing toward a Regional Capital"))
        XCTAssertFalse(presentation.objective.contains("2,500"))
    }

    func testFirstRunGuidanceExplainsBothGrowthStrategiesAndTheirTradeoff() throws {
        let growth = try XCTUnwrap(presentation.tips.first { $0.title == "Choose Growth" })

        XCTAssertTrue(growth.detail.contains("Commercial Stewardship is cleaner"))
        XCTAssertTrue(growth.detail.contains("Industrial Expansion adds jobs faster"))
        XCTAssertTrue(growth.detail.contains("more pollution and utility load"))
    }

    func testFirstRunGuidancePointsPlayersToDiagnosisToolsAndOpeningPressures() throws {
        let stabilize = try XCTUnwrap(presentation.tips.first { $0.title == "Stabilize" })
        let diagnose = try XCTUnwrap(presentation.tips.first { $0.title == "Diagnose" })

        XCTAssertTrue(stabilize.detail.contains("cashflow, utilities, happiness, and jobs"))
        XCTAssertTrue(diagnose.detail.contains("inspector and data overlays"))
        XCTAssertTrue(diagnose.detail.contains("budget pressure"))
    }

    func testAccessibilitySummaryCarriesTheWholeFirstRunJourneyAndKeyboardActivation() {
        let summary = presentation.accessibilitySummary

        XCTAssertTrue(summary.contains(presentation.objective))
        XCTAssertTrue(summary.contains("Commercial Stewardship is cleaner"))
        XCTAssertTrue(summary.contains("Industrial Expansion adds jobs faster"))
        XCTAssertTrue(summary.contains("Use the inspector and data overlays"))
        XCTAssertTrue(summary.contains("Space pauses · 1–3 set speed · ⌘Z undoes"))
        XCTAssertTrue(summary.contains("Press Return or choose Start Building to continue"))
    }
}
