import AppKit
import SwiftUI
import Vision
import XCTest
@testable import CitySimNative

final class CityDevelopmentUtilityTests: XCTestCase {
    func testDiagnosisUsesBothAuthoritativeNetworksAndHandlesTiesAndHealthySites() {
        for (power, water, expected): (Double, Double, [DataOverlay]) in [
            (0.25, 1, [.power]), (1, 0.25, [.water]), (0.25, 0.25, [.power, .water]), (1, 1, []),
        ] {
            let service = CityLocationUtilityService(
                power: power, water: water, combined: min(power, water),
                powerBand: power == 1 ? .healthy : .severe,
                waterBand: water == 1 ? .healthy : .severe,
                combinedBand: min(power, water) == 1 ? .healthy : .severe
            )
            let diagnosis = CityDevelopmentUtilityPresentation(service: service)
            XCTAssertEqual(diagnosis.networks.map(\.percent), [Int(power * 100), Int(water * 100)])
            XCTAssertEqual(diagnosis.networks.filter(\.limitsSite).map(\.overlay), expected)
            XCTAssertTrue(diagnosis.accessibilitySummary.contains("After completion"))
        }
    }

    func testDevelopmentDiagnosisComesFromTheCompletedSiteWithoutChangingTheCity() throws {
        let state = CityGameState.newCity(seed: 42)
        let fingerprint = try CityStateFingerprinter.fingerprint(state)
        for kind in [BuildingKind.residential, .commercial, .industrial] {
            let target = try eligibleSite(kind: kind, state: state)
            let forecast = try XCTUnwrap(CityDevelopmentSiteForecast.make(kind: kind, at: target, in: state))
            var completed = state
            guard case .success = CitySimulation.build(kind, at: target, in: &completed) else {
                return XCTFail("Fixture must permit the proposed development")
            }
            completed.updateTile(at: target) { $0.constructionProgress = 1; $0.condition = 1 }
            let service = try XCTUnwrap(CitySpatialConsequenceMap(state: completed)[target]?.utility)
            XCTAssertEqual(forecast.utility, service)
            XCTAssertEqual(forecast.utilityService, service.combined)
            let decision = CityBuildDecisionPresentation.make(
                kind: kind, tile: try XCTUnwrap(state.tile(at: target)), rejection: nil, state: state
            )
            XCTAssertEqual(decision.developmentUtility, CityDevelopmentUtilityPresentation(service: service))
            XCTAssertTrue(decision.accessibilitySummary.contains("power service"))
            XCTAssertTrue(decision.accessibilitySummary.contains("water service"))
        }
        XCTAssertEqual(try CityStateFingerprinter.fingerprint(state), fingerprint)
        let target = try eligibleSite(kind: .commercial, state: state)
        let tile = try XCTUnwrap(state.tile(at: target))
        XCTAssertNil(CityBuildDecisionPresentation.make(
            kind: .commercial, tile: tile, rejection: .roadAccessRequired, state: state
        ).developmentUtility, "A rejected project must not advertise a completion forecast")
        XCTAssertNil(CityBuildDecisionPresentation.make(
            kind: .powerPlant, tile: tile, rejection: nil, state: state
        ).developmentUtility, "Utility infrastructure retains its existing supply and pollution forecast")
    }

    @MainActor
    func testNetworkInspectionRetainsPendingSiteForecastAndCityAndHonorsModalGuards() throws {
        let store = CityGameStore(state: .newCity(seed: 42))
        store.speed = .paused
        let target = try eligibleSite(kind: .commercial, state: store.state)
        store.selectTool(.commercial)
        let decision = try XCTUnwrap(store.acceptPointerMapActionCandidate(target)?.primaryAction.buildDecision)
        let before = store.state
        let focus = store.mapFocusRequestGeneration
        for (network, expected) in [(DataOverlay.power, DataOverlay.power), (.water, .water), (.water, .none)] {
            XCTAssertTrue(store.toggleDevelopmentUtilityOverlay(network))
            XCTAssertEqual(store.overlay, expected)
            XCTAssertEqual(store.selectedCoordinate, target)
            XCTAssertEqual(store.interactionMode, .build(.commercial))
            XCTAssertEqual(store.activeMapActionTargetPresentation?.primaryAction.buildDecision, decision)
            XCTAssertEqual(store.state, before)
            XCTAssertFalse(store.canUndo)
        }
        XCTAssertEqual(store.mapFocusRequestGeneration, focus + 3)
        XCTAssertFalse(store.toggleDevelopmentUtilityOverlay(.pollution))
        store.presentBlockingModal(.checkpointLibrary)
        XCTAssertFalse(store.toggleDevelopmentUtilityOverlay(.power))
        XCTAssertEqual(store.overlay, .none)
        XCTAssertEqual(store.state, before)
        XCTAssertTrue(store.dismissBlockingModal(.checkpointLibrary))
        store.cancelBuildDecision()
        XCTAssertFalse(store.toggleDevelopmentUtilityOverlay(.power))
        XCTAssertEqual(store.state, before)
    }

    @MainActor
    func testUtilityControlsAndPurchaseFactsFitTheUnexpandedDecisionDeck() throws {
        for compact in [true, false] {
            let store = CityGameStore(state: .newCity(seed: 42))
            store.speed = .paused
            store.selectTool(.commercial)
            store.selectedCoordinate = try eligibleSite(kind: .commercial, state: store.state)
            store.clearFeedback()
            let diagnosis = try XCTUnwrap(store.activeMapActionTargetPresentation?.primaryAction.buildDecision?.developmentUtility)
            let width: CGFloat = compact ? 780 : 860
            let host = NSHostingView(rootView:
                BuildToolbarView(store: store, compact: compact, pointerTransitionGate: CityMapPointerTransitionGate())
                    .preferredColorScheme(.dark).frame(width: width, height: 112)
            )
            host.frame = CGRect(x: 0, y: 0, width: width, height: 112)
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            try VNImageRequestHandler(cgImage: XCTUnwrap(bitmap.cgImage)).perform([request])
            let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ").lowercased()
                .replacingOccurrences(of: ", ", with: ",")
            for required in diagnosis.networks.map(\.title) + ["limits site", "build here", "cancel", "$2,400", "online in 4 ticks", "net on completion"] {
                XCTAssertTrue(text.contains(required.lowercased()), "\(compact): missing \(required): \(text)")
            }
        }
    }

    private func eligibleSite(kind: BuildingKind, state: CityGameState) throws -> GridCoordinate {
        try XCTUnwrap(state.tiles.first { tile in
            guard case .success = CitySimulation.validateBuild(kind, at: tile.coordinate, in: state),
                  let forecast = CityDevelopmentSiteForecast.make(kind: kind, at: tile.coordinate, in: state) else {
                return false
            }
            return forecast.utility.combinedBand != .healthy
        }?.coordinate)
    }
}
