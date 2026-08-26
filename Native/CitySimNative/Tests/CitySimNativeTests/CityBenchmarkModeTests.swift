import AppKit
import SwiftUI
import XCTest
@testable import CitySimNative

final class CityBenchmarkModeTests: XCTestCase {
    func testKnownWorkloadIsDeterministicDevelopedAndPlayable() throws {
        let definition = CityBenchmarkDefinition.verticalSlice
        let first = definition.makeState()
        let second = definition.makeState()

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.gridWidth, 24)
        XCTAssertEqual(first.gridHeight, 24)
        XCTAssertEqual(definition.ticksPerPulse, SimulationSpeed.fastest.ticksPerPulse)
        XCTAssertEqual(definition.pulseWorkload, "400 × 3 ticks")
        XCTAssertGreaterThan(first.tiles.filter { $0.kind != .empty }.count, 300)
        XCTAssertGreaterThan(first.tiles.filter { $0.kind == .powerPlant }.count, 10)
        XCTAssertGreaterThan(first.tiles.filter { $0.kind == .waterTower }.count, 10)
        XCTAssertEqual(
            try CityStateFingerprinter.fingerprint(first),
            try CityStateFingerprinter.fingerprint(second)
        )
    }

    func testRunnerProducesStableOutcomeAndMeasuredPerformance() async throws {
        let first = try await CityBenchmarkRunner.run()
        let second = try await CityBenchmarkRunner.run()

        XCTAssertEqual(first.benchmarkID, "native-dense-3x-v2")
        XCTAssertEqual(first.pulseCount, 400)
        XCTAssertEqual(first.logicalTicks, 1_200)
        XCTAssertEqual(first.finalStatus, GameStatus.playing.rawValue)
        XCTAssertEqual(first.finalFingerprint, second.finalFingerprint)
        XCTAssertEqual(first.finalFingerprint, CityBenchmarkDefinition.verticalSlice.expectedFinalFingerprint)
        XCTAssertTrue(first.fingerprintVerified)
        XCTAssertEqual(first.finalPopulation, second.finalPopulation)
        XCTAssertEqual(first.finalTreasury, second.finalTreasury)
        XCTAssertGreaterThan(first.totalMilliseconds, 0)
        XCTAssertGreaterThan(first.p95PulseMilliseconds, 0)
        XCTAssertGreaterThan(first.pulsesPerSecond, 0)
        XCTAssertTrue(first.withinProvisionalBudget)
        XCTAssertLessThanOrEqual(
            first.averagePulseMilliseconds,
            CityBenchmarkDefinition.verticalSlice.provisionalPulseBudgetMilliseconds
        )
        XCTAssertLessThanOrEqual(
            first.p95PulseMilliseconds,
            CityBenchmarkDefinition.verticalSlice.provisionalPulseBudgetMilliseconds
        )
    }

    func testRunnerCancellationStopsTheTemporaryWorkload() async {
        let definition = CityBenchmarkDefinition(
            id: "cancellation-fixture",
            title: "Cancellation Fixture",
            detail: "Exercises the cancellation boundary.",
            seed: 42,
            pulseCount: 100_000,
            ticksPerPulse: SimulationSpeed.fastest.ticksPerPulse,
            provisionalPulseBudgetMilliseconds: 16,
            expectedFinalFingerprint: nil
        )
        let task = Task { try await CityBenchmarkRunner.run(definition: definition) }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Canceled benchmark unexpectedly completed")
        } catch {
            XCTAssertEqual(error as? CityBenchmarkRunError, .canceled)
        }
    }

    func testReportExportIsVersionedPrivacySafeAndNonDestructive() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-benchmark-report-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = CityBenchmarkReportService(reportDirectoryURL: root)
        let result = Self.resultFixture
        let generatedAt = Date(timeIntervalSince1970: 1_786_570_000)

        let url = try service.export(result: result, generatedAt: generatedAt)
        let data = try Data(contentsOf: url)
        let report = try JSONDecoder.cityBenchmarkDecoder.decode(CityBenchmarkReport.self, from: data)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertEqual(report.reportVersion, 1)
        XCTAssertEqual(report.generatedAt, generatedAt)
        XCTAssertEqual(report.result, result)
        XCTAssertEqual(url.lastPathComponent, "native-dense-3x-v2.json")
        XCTAssertTrue(report.qualification.contains("3×"))
        XCTAssertTrue(report.qualification.contains("not certify"))
        XCTAssertFalse(text.contains(FileManager.default.homeDirectoryForCurrentUser.path))
        XCTAssertFalse(text.contains("New Arcadia"))
    }

    @MainActor
    func testStoreRunsExportsAndClosesBenchmarkWithoutChangingCityOrSaves() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-benchmark-store-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let saveRoot = root.appending(path: "saves", directoryHint: .isDirectory)
        let reportRoot = root.appending(path: "reports", directoryHint: .isDirectory)
        let saveService = SaveGameService(rootURL: saveRoot)
        var original = CityGameState.newCity(seed: 77)
        original.tick = 4
        var revealedURLs = [URL]()
        let store = CityGameStore(
            state: original,
            saveService: saveService,
            benchmarkReportService: CityBenchmarkReportService(reportDirectoryURL: reportRoot),
            revealSupportReport: { revealedURLs.append($0) }
        )
        store.setSpeed(.fast)

        XCTAssertTrue(store.perform(.newRegion))
        XCTAssertEqual(store.speed, .paused)
        XCTAssertEqual(store.sessionReplacementConfirmation?.action, .newRegion)
        XCTAssertTrue(store.confirmSessionReplacement())
        store.updateNewRegionExperience(.benchmark)
        XCTAssertTrue(store.createNewRegion())
        XCTAssertNil(store.newRegionSetup)
        XCTAssertEqual(store.benchmarkSession?.phase, .ready)
        XCTAssertEqual(store.state, original)
        XCTAssertFalse(saveService.hasResumeCandidate)

        XCTAssertTrue(store.startBenchmark())
        for _ in 0..<300 where store.benchmarkSession?.phase == .running {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(store.benchmarkSession?.phase, .complete)
        XCTAssertEqual(store.benchmarkSession?.result?.logicalTicks, 1_200)
        XCTAssertEqual(store.state, original)
        XCTAssertFalse(saveService.hasResumeCandidate)

        XCTAssertTrue(store.exportBenchmarkReport())
        XCTAssertEqual(revealedURLs.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(revealedURLs.first).path))
        XCTAssertEqual(store.state, original)

        XCTAssertTrue(store.closeBenchmark())
        XCTAssertNil(store.benchmarkSession)
        XCTAssertEqual(store.commandPolicy, .enabled)
        XCTAssertEqual(store.state, original)
        XCTAssertEqual(store.speed, .fast)
    }

    @MainActor
    func testReadyAndResultSurfacesRenderAtAcceptanceSizes() throws {
        let ready = CityBenchmarkSessionPresentation.ready()
        var complete = ready
        complete.phase = .complete
        complete.completedPulses = complete.definition.pulseCount
        complete.result = Self.resultFixture
        var draft = CityNewRegionDraft.initial(seed: 42)
        draft.experience = .benchmark

        for size in [CGSize(width: 900, height: 600), CGSize(width: 1_280, height: 800)] {
            let readyImage = try bitmap(of: view(for: ready, size: size), size: size)
            let resultImage = try bitmap(of: view(for: complete, size: size), size: size)
            let chooserImage = try bitmap(
                of: NewRegionSetupView(
                    presentation: .standard,
                    draft: draft,
                    updateExperience: { _ in },
                    updateScenario: { _ in },
                    updateCityName: { _ in },
                    updateSeed: { _ in },
                    updateStartingResources: { _ in },
                    updateSandboxEconomy: { _ in },
                    updateSandboxIncidents: { _ in },
                    updateSandboxUnlimitedFunds: { _ in },
                    createAction: {},
                    cancelAction: {}
                )
                .frame(width: size.width, height: size.height),
                size: size
            )
            XCTAssertEqual(readyImage.size.width, size.width, accuracy: 0.5)
            XCTAssertEqual(resultImage.size.height, size.height, accuracy: 0.5)
            XCTAssertEqual(chooserImage.size.width, size.width, accuracy: 0.5)
            if size.width > 1_000,
               let path = ProcessInfo.processInfo.environment["CITYSIM_BENCHMARK_PROOF"] {
                let data = try XCTUnwrap(resultImage.representation(using: .png, properties: [:]))
                try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            }
            if size.width > 1_000,
               let path = ProcessInfo.processInfo.environment["CITYSIM_BENCHMARK_CHOOSER_PROOF"] {
                let data = try XCTUnwrap(chooserImage.representation(using: .png, properties: [:]))
                try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            }
            if size.width < 1_000,
               let path = ProcessInfo.processInfo.environment["CITYSIM_BENCHMARK_COMPACT_PROOF"] {
                let data = try XCTUnwrap(chooserImage.representation(using: .png, properties: [:]))
                try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            }
        }
    }

    private static let resultFixture = CityBenchmarkResult(
        benchmarkID: "native-dense-3x-v2",
        pulseCount: 400,
        logicalTicks: 1_200,
        developedTiles: 364,
        totalMilliseconds: 2_760,
        averagePulseMilliseconds: 6.9,
        p95PulseMilliseconds: 8.2,
        pulsesPerSecond: 145,
        finalFingerprint: "98bb126a2026e4e4e10a2ab63fd6b7673d10316bb5b7464b0ebd1f04fbecb25f",
        finalPopulation: 3_238,
        finalTreasury: 5_114_880,
        finalStatus: "playing",
        withinProvisionalBudget: true,
        fingerprintVerified: true
    )

    @MainActor
    private func view(
        for session: CityBenchmarkSessionPresentation,
        size: CGSize
    ) -> some View {
        CityBenchmarkView(
            session: session,
            runAction: {},
            cancelRunAction: {},
            exportAction: {},
            backAction: {},
            doneAction: {}
        )
        .frame(width: size.width, height: size.height)
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

private extension JSONDecoder {
    static var cityBenchmarkDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
