import AppKit
import SwiftUI
import XCTest
@testable import CitySimNative

final class CityHistoryTests: XCTestCase {
    func testNewCityRecordsDeterministicDailyHistory() throws {
        var first = CityGameState.newTrackedCity(seed: 2_026_081_212)
        var second = CityGameState.newTrackedCity(seed: 2_026_081_212)

        XCTAssertEqual(first.cityHistory?.map(\.tick), [0])
        for _ in 0..<12 {
            CitySimulation.step(&first)
            CitySimulation.step(&second)
        }

        let history = try XCTUnwrap(first.cityHistory)
        XCTAssertEqual(history.map(\.tick), [0, 4, 8, 12])
        XCTAssertEqual(history.map(\.day), [1, 2, 3, 4])
        XCTAssertEqual(first.cityHistory, second.cityHistory)
        XCTAssertEqual(history.last?.population, first.population)
        XCTAssertEqual(history.last?.treasury, first.treasury)
        XCTAssertEqual(
            try XCTUnwrap(history.last).projectedBalance,
            CitySimulation.projectedBalance(in: first),
            accuracy: 0.001
        )
    }

    func testHistoryRetainsLatestNinetyDailySamples() throws {
        var state = CityGameState.newTrackedCity(seed: 42)
        for day in 1...100 {
            state.tick = day * 4
            state.population += 1
            state.recordHistorySample()
        }

        let history = try XCTUnwrap(state.cityHistory)
        XCTAssertEqual(history.count, CityGameState.maximumHistorySampleCount)
        XCTAssertEqual(history.first?.tick, 44)
        XCTAssertEqual(history.last?.tick, 400)
        XCTAssertEqual(history.last?.population, state.population)
    }

    func testHistoryRoundTripsWithSaveFingerprint() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-history-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        var state = CityGameState.newTrackedCity(seed: 77)
        for _ in 0..<8 { CitySimulation.step(&state) }

        let write = try service.save(state)
        let load = try service.load()

        XCTAssertEqual(load.state, state)
        XCTAssertEqual(load.state.cityHistory, state.cityHistory)
        XCTAssertEqual(load.fingerprint, write.fingerprint)
    }

    func testLegacyStateWithoutHistoryKeepsItsCanonicalIdentityAndDoesNotInventSamples() throws {
        var legacy = CityGameState.newCity(seed: 88)
        let before = try CityStateFingerprinter.fingerprint(legacy)
        let bytes = try CityStateFingerprinter.canonicalData(for: legacy)
        XCTAssertFalse(String(decoding: bytes, as: UTF8.self).contains("cityHistory"))

        for _ in 0..<4 { CitySimulation.step(&legacy) }

        XCTAssertNil(legacy.cityHistory)
        XCTAssertNotEqual(try CityStateFingerprinter.fingerprint(legacy), before)
    }

    @MainActor
    func testTrendsCommandOpensAccessibleRenderableSection() throws {
        let store = CityGameStore(state: .newTrackedCity(seed: 99), startsPaused: true)
        for _ in 0..<12 { CitySimulation.step(&store.state) }

        XCTAssertEqual(CityCommandCatalog.inspectorSection(for: .inspectorTrends), .trends)
        XCTAssertEqual(CityCommandCatalog.id(for: .trends), .inspectorTrends)
        XCTAssertTrue(store.perform(.inspectorTrends))
        XCTAssertTrue(store.showInspector)
        XCTAssertEqual(store.inspectorSection, .trends)

        let view = NSHostingView(
            rootView: InspectorView(store: store)
                .frame(width: 1_180, height: 250)
        )
        view.frame = CGRect(x: 0, y: 0, width: 1_180, height: 250)
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        XCTAssertGreaterThan(bitmap.pixelsWide, 1_000)
        XCTAssertGreaterThan(bitmap.pixelsHigh, 200)
    }

    func testConfiguredModesRefreshTheirDayOneBaseline() throws {
        var draft = CityNewRegionDraft.initial(seed: 101)
        draft.experience = .openSandbox
        draft.cityName = "Trend Harbor"
        draft.startingResources = .generous
        let sandbox = try XCTUnwrap(draft.configuration?.makeState())
        let scenario = CityAuthoredScenarioCatalog.harborRecovery.makeState()

        XCTAssertEqual(sandbox.cityHistory?.first?.treasury, 60_000)
        XCTAssertEqual(sandbox.cityHistory?.first?.population, sandbox.population)
        XCTAssertEqual(scenario.cityHistory?.first?.treasury, 16_000)
        XCTAssertEqual(scenario.cityHistory?.first?.population, 360)
    }
}
