import AppKit
import SwiftUI
import Vision
import XCTest
@testable import CitySimNative

final class CityUtilityReadabilityTests: XCTestCase {
    @MainActor
    func testUtilityPanelHasBoundedRoomWithoutChangingOtherInspectors() {
        for compact in [true, false] {
            XCTAssertEqual(BuildToolbarView.detailsHeight(compact: compact, selectedBlock: false, utilities: true), 248)
            XCTAssertEqual(BuildToolbarView.detailsHeight(compact: compact, selectedBlock: true, utilities: true), 220)
        }
        XCTAssertEqual(BuildToolbarView.detailsHeight(compact: true, selectedBlock: false), 196)
        XCTAssertEqual(BuildToolbarView.detailsHeight(compact: false, selectedBlock: false), 144)
        XCTAssertEqual(BuildToolbarView.detailsHeight(compact: false, selectedBlock: false, finances: true), 216)
    }

    @MainActor
    func testBothNetworksAndEveryPrimaryActionAreVisibleWithoutScrolling() throws {
        for compact in [true, false] {
            let size = compact ? CGSize(width: 900, height: 600) : CGSize(width: 1280, height: 800)
            for (powerUse, waterUse) in [(256, 231), (599, 200), (601, 271)] {
                var state = CityGameState.newCity(seed: 42)
                state.powerCapacity = 600
                state.waterCapacity = 270
                state.powerUsed = powerUse
                state.waterUsed = waterUse
                let store = CityGameStore(state: state)
                store.speed = .paused
                store.openInspector(.utilities)
                let fingerprint = try CityStateFingerprinter.fingerprint(store.state)
                var frames = CityHUDChromeFrames()
                let host = NSHostingView(rootView: ContentView(store: store) { frames = $0 }
                    .transaction { $0.disablesAnimations = true }
                    .preferredColorScheme(.dark)
                    .frame(width: size.width, height: size.height))
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
                for required in ["power", "water", "build power", "build water", "power map", "water map", "weak blocks", "local service"] {
                    XCTAssertTrue(text.contains(required), "\(size), \(powerUse)/\(waterUse): missing \(required): \(text)")
                }
                let compactText = text.replacingOccurrences(of: " ", with: "")
                XCTAssertTrue(compactText.contains("\(powerUse)/600"), text)
                XCTAssertTrue(compactText.contains("\(waterUse)/270"), text)
                let support = CityUtilityDecisionSupport.make(analytics: store.analytics)
                let reach = CityUtilityReachPresentation(state: store.state)
                let title = reach.priorityWhenCapacityAvailable(support)?.planningTitle ?? support.title
                XCTAssertTrue(text.contains(title.lowercased()), text)
                XCTAssertLessThanOrEqual(frames.inspector.height, 264)
                XCTAssertGreaterThan(frames.inspector.minY, size.height * 0.35)
                XCTAssertEqual(try CityStateFingerprinter.fingerprint(store.state), fingerprint)
                XCTAssertFalse(store.canUndo)
            }
        }
    }
}
