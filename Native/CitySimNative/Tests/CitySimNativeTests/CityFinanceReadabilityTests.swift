import AppKit
import SwiftUI
import Vision
import XCTest
@testable import CitySimNative

final class CityFinanceReadabilityTests: XCTestCase {
    @MainActor
    func testFinanceSpaceIsBoundedAndDoesNotChangeOtherPanels() {
        XCTAssertEqual(BuildToolbarView.detailsHeight(compact: false, selectedBlock: false, finances: true), 216)
        XCTAssertEqual(BuildToolbarView.detailsHeight(compact: true, selectedBlock: false, finances: true), 196)
        XCTAssertEqual(BuildToolbarView.detailsHeight(compact: false, selectedBlock: false), 144)
        XCTAssertEqual(BuildToolbarView.detailsHeight(compact: false, selectedBlock: true, finances: true), 220)
    }

    @MainActor
    func testPolicyChoicesAndConsequencesAreVisibleInTheComposedFinancePanel() throws {
        for compact in [true, false] {
            let size = compact ? CGSize(width: 900, height: 600) : CGSize(width: 1280, height: 800)
            for (roads, services) in [
                (CityRoadMaintenancePolicy.routine, CityCivicServiceFundingPolicy.standard),
                (.preventive, .expanded),
                (.deferred, .reduced),
            ] {
                var state = CityGameState.newCity(seed: 42)
                let school = try XCTUnwrap(state.tiles.first { $0.kind == .empty }?.coordinate)
                state.updateTile(at: school) { $0 = CityTile(coordinate: school, kind: .school) }
                let damagedRoad = try XCTUnwrap(state.tiles.first { $0.kind == .road }?.coordinate)
                state.updateTile(at: damagedRoad) { $0.condition = 0.4 }
                let store = CityGameStore(state: state)
                store.speed = .paused
                store.setRoadMaintenancePolicy(roads)
                store.setCivicServiceFundingPolicy(services)
                store.openInspector(.finances)
                store.clearFeedback()
                let fingerprint = try CityStateFingerprinter.fingerprint(store.state)
                var frames = CityHUDChromeFrames()
                let host = NSHostingView(rootView:
                    ContentView(store: store) { frames = $0 }
                        .transaction { $0.disablesAnimations = true }
                        .preferredColorScheme(.dark)
                        .frame(width: size.width, height: size.height)
                )
                host.frame = CGRect(origin: .zero, size: size)
                for _ in 0..<4 {
                    host.layoutSubtreeIfNeeded()
                    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
                }
                let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["en-US"]
                try VNImageRequestHandler(cgImage: XCTUnwrap(bitmap.cgImage)).perform([request])
                let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ").lowercased()
                for required in [
                    "roads", "services", roads.title, services.title,
                    "resurface 1", "damaged",
                    "\(services.maximumRoadDistance) blocks", services.stormReadinessSummary,
                    CitySimulation.projectedRoadMaintenanceUpkeep(in: store.state).currencyText,
                    CitySimulation.projectedCivicServiceUpkeep(in: store.state).currencyText,
                ] {
                    XCTAssertTrue(text.contains(required.lowercased()), "\(size): missing \(required): \(text)")
                }
                if !compact {
                    for required in ["treasury", "revenue", "upkeep", "net", "decision support"] {
                        XCTAssertTrue(text.contains(required), "Budget comparison must remain visible: \(text)")
                    }
                }
                XCTAssertLessThanOrEqual(frames.inspector.height, compact ? 212 : 232)
                XCTAssertGreaterThan(frames.inspector.minY, size.height * 0.45)
                XCTAssertEqual(try CityStateFingerprinter.fingerprint(store.state), fingerprint)
            }
        }
    }
}
