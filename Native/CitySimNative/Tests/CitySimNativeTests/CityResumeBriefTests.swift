import Foundation
import XCTest
@testable import CitySimNative

final class CityResumeBriefTests: XCTestCase {
    func testOpeningWarningBecomesTheReturningPlayersFirstExactAction() throws {
        var state = CityGameState.newCity(seed: 42)
        for _ in 0..<4 { CitySimulation.step(&state) }

        let brief = try XCTUnwrap(
            CityResumeBriefPresentation.make(analytics: CityAnalytics(state: state))
        )

        XCTAssertEqual(state.messages.first?.title, "Budget Gap")
        XCTAssertEqual(brief.title, "Budget Gap")
        XCTAssertEqual(brief.nextAction, "Review finances")
        XCTAssertEqual(brief.command, .inspectorFinances)
        XCTAssertTrue(brief.detail.localizedCaseInsensitiveContains("operations"))
        XCTAssertEqual(brief.compactText, "Budget Gap · Next: Review finances")
        XCTAssertTrue(brief.accessibilitySummary.contains("Next: Review finances"))
    }

    func testResumeBriefUsesLiveCharterAndRegionalQualificationBlockers() throws {
        var charter = progressedState(secondAct: nil)
        charter.population = 490
        charter.powerCapacity = 600
        charter.waterCapacity = 600
        charter.powerUsed = 300
        charter.waterUsed = 300
        charter.messages = []

        let charterBrief = try XCTUnwrap(
            CityResumeBriefPresentation.make(analytics: CityAnalytics(state: charter))
        )
        XCTAssertEqual(charterBrief.title, "Prepare 125 jobs")
        XCTAssertEqual(charterBrief.nextAction, "Build Commercial")
        XCTAssertEqual(charterBrief.command, .buildCommercial)
        XCTAssertTrue(charterBrief.detail.contains("prepare 125 jobs"))

        var regional = progressedState(secondAct: CitySecondActProgression(
            phase: .qualification,
            nextScheduledTick: nil,
            qualifyingCycles: 3,
            regionalCapitalAwarded: false
        ))
        regional.population = 520
        regional.messages = []

        let regionalBrief = try XCTUnwrap(
            CityResumeBriefPresentation.make(analytics: CityAnalytics(state: regional))
        )
        XCTAssertEqual(regionalBrief.title, "Grow to 525 residents")
        XCTAssertEqual(regionalBrief.nextAction, "Build homes")
        XCTAssertEqual(regionalBrief.command, .buildResidential)
        XCTAssertTrue(regionalBrief.detail.contains("5 more residents"))
    }

    @MainActor
    func testPrimaryAndBackupLoadsKeepActionableBriefVisibleUntilDismissed() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-resume-brief-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)

        var saved = CityGameState.newCity(seed: 42)
        for _ in 0..<4 { CitySimulation.step(&saved) }
        try service.save(saved)

        let primary = CityGameStore(saveService: service, startsPaused: true)
        XCTAssertTrue(primary.perform(.loadCity))
        XCTAssertEqual(primary.lastFeedback, "City loaded · Simulation paused")
        XCTAssertEqual(primary.resumeBrief?.compactText, "Budget Gap · Next: Review finances")
        XCTAssertEqual(primary.speed, .paused)
        XCTAssertTrue(primary.performResumeBriefAction())
        XCTAssertNil(primary.lastFeedback)
        XCTAssertNil(primary.resumeBrief)
        XCTAssertTrue(primary.showInspector)
        XCTAssertEqual(primary.inspectorSection, .finances)
        XCTAssertEqual(primary.speed, .paused)

        var newer = saved
        CitySimulation.step(&newer)
        try service.save(newer)
        try Data("corrupt".utf8).write(to: service.saveURL, options: .atomic)

        let recovered = CityGameStore(saveService: service, startsPaused: true)
        XCTAssertTrue(recovered.perform(.loadCity))
        XCTAssertEqual(
            recovered.lastFeedback,
            "Recovered last known-good city · Simulation paused"
        )
        XCTAssertEqual(recovered.resumeBrief?.title, "Budget Gap")
        XCTAssertEqual(recovered.resumeBrief?.nextAction, "Review finances")
        XCTAssertEqual(recovered.state, saved)
        XCTAssertEqual(recovered.speed, .paused)
    }

    func testTerminalLoadsDeferToTheBlockingResultInsteadOfInventingAResumeTask() {
        var terminal = CityGameState.newCity(seed: 7)
        terminal.status = .won

        XCTAssertNil(
            CityResumeBriefPresentation.make(analytics: CityAnalytics(state: terminal))
        )
    }

    private func progressedState(
        secondAct: CitySecondActProgression?
    ) -> CityGameState {
        var state = CityGameState.newCity(seed: 0xBEEF)
        state.progression = CityProgressionState(
            townCharterQualifyingCycles: secondAct == nil ? 0 : CitySimulation.townCharterQualificationCycles,
            townCharterAwarded: secondAct != nil,
            strategy: CityStrategyProgression(
                committedStrategy: .commercialStewardship,
                currentPhase: .completed,
                nextScheduledTick: nil,
                recoveryResolution: .commercialPublicRealmInvestment
            ),
            secondAct: secondAct
        )
        state.treasury = 20_000
        state.happiness = 65
        state.jobs = 330
        state.powerCapacity = 600
        state.waterCapacity = 600
        state.powerUsed = 300
        state.waterUsed = 300
        return state
    }
}
