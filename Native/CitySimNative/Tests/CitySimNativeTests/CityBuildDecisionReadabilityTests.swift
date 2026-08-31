import AppKit
import SwiftUI
import Vision
import XCTest
@testable import CitySimNative

final class CityBuildDecisionReadabilityTests: XCTestCase {
    @MainActor
    func testRenderedBuildCommitmentAndRecoveryRemainReadableInTheExistingDeck() throws {
        let authored = CityGameState.newCity(seed: 42)
        let open = try XCTUnwrap(authored.tiles.first { tile in
            if case .success = CitySimulation.validateBuild(.residential, at: tile.coordinate, in: authored) {
                return true
            }
            return false
        }?.coordinate)
        let roadless = try XCTUnwrap(authored.tiles.first { tile in
            if case .failure(.roadAccessRequired) = CitySimulation.validateBuild(.residential, at: tile.coordinate, in: authored) {
                return true
            }
            return false
        }?.coordinate)

        for compact in [true, false] {
            for (kind, target, unfunded, action) in [
                (BuildingKind.powerPlant, open, true, "review finances"),
                (.residential, roadless, false, "target adjacent road"),
                (.residential, open, false, "build here"),
            ] {
                var state = authored
                if unfunded { state.treasury = 0 }
                let store = CityGameStore(state: state)
                store.speed = .paused
                store.selectTool(kind)
                store.selectedCoordinate = target
                store.clearFeedback()
                let decision = try XCTUnwrap(store.activeMapActionTargetPresentation?.primaryAction.buildDecision)
                let fingerprint = try CityStateFingerprinter.fingerprint(store.state)
                let width: CGFloat = compact ? 780 : 860
                let host = NSHostingView(rootView:
                    BuildToolbarView(store: store, compact: compact, pointerTransitionGate: CityMapPointerTransitionGate())
                        .preferredColorScheme(.dark)
                        .frame(width: width, height: 112)
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
                XCTAssertTrue(text.contains("online in 4 ticks"), "\(compact), \(kind): \(text)")
                XCTAssertTrue(text.contains(kind.buildCost.currencyText.lowercased()), text)
                XCTAssertTrue(text.contains(action), "The actual rendered action, not only its AX label, must fit: \(text)")
                XCTAssertTrue(text.contains("cancel"), text)
                XCTAssertTrue(decision.accessibilitySummary.contains(decision.cost))
                XCTAssertEqual(try CityStateFingerprinter.fingerprint(store.state), fingerprint)
            }
        }
    }
}
