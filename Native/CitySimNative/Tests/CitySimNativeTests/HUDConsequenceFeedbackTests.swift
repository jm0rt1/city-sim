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
}
