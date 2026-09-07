import AppKit
import SpriteKit
import SwiftUI
import Vision
import XCTest
@testable import CitySimNative

final class CityUtilityExpenseSitesTests: XCTestCase {
    func testFacilitySharesReconcileLevelsReservesAndEveryEconomyWithoutMutation() throws {
        for economy in CitySandboxEconomy.allCases {
            var state = district()
            state.sandboxRules = .init(economy: economy, incidentsEnabled: true, unlimitedFunds: true)
            state.updateTile(at: .init(x: 4, y: 8)) { $0.level = 2 }
            state.updateTile(at: .init(x: 2, y: 8)) { $0.kind = .powerPlant; $0.constructionProgress = 0.5 }
            let original = state
            let expenses = CityOperatingExpensePresentation.make(in: state)
            let utilities = try XCTUnwrap(expenses.rows.first { $0.category == .utilities })
            XCTAssertEqual(expenses.utilitySites.count, 4)
            XCTAssertEqual(expenses.utilitySites.reduce(0) { $0 + $1.upkeep.amount }, utilities.amount, accuracy: 0.000_001)
            XCTAssertEqual(expenses.utilitySites.map(\.upkeep.amount), expenses.utilitySites.map(\.upkeep.amount).sorted(by: >))
            XCTAssertEqual(expenses.utilitySites.first?.coordinate, .init(x: 4, y: 8))
            for site in expenses.utilitySites {
                let tile = try XCTUnwrap(state.tile(at: site.coordinate))
                XCTAssertEqual(site.upkeep, CityBlockUpkeepPresentation.make(for: tile, in: state))
                XCTAssertTrue(site.accessibilitySummary.contains("not demolition savings"))
                XCTAssertTrue(site.accessibilitySummary.contains(site.block))
            }
            XCTAssertEqual(state, original)
            XCTAssertEqual(try JSONDecoder().decode(CityGameState.self, from: JSONEncoder().encode(state)), original)
        }
    }

    @MainActor
    func testFindUsesTheExactFacilityAndRejectsInvalidOrBlockedRequests() throws {
        let store = CityGameStore(state: district(), startsPaused: true)
        let original = store.state
        for coordinate in [GridCoordinate(x: 3, y: 9), .init(x: 4, y: 8)] {
            store.openInspector(.finances)
            let generation = store.diagnosticFocusRequestGeneration
            XCTAssertTrue(CityUtilityExpenseSitesView.find(coordinate, on: store))
            XCTAssertEqual(store.selectedCoordinate, coordinate)
            XCTAssertEqual(store.overlay, coordinate.x == 3 ? .water : .power)
            XCTAssertEqual(store.interactionMode, .inspect)
            XCTAssertFalse(store.showInspector)
            XCTAssertEqual(store.diagnosticFocusRequestGeneration, generation + 1)
            XCTAssertEqual(store.state, original)
            XCTAssertFalse(store.canUndo)
        }
        let selected = store.selectedCoordinate
        let overlay = store.overlay
        let generation = store.diagnosticFocusRequestGeneration
        XCTAssertFalse(CityUtilityExpenseSitesView.find(.init(x: 0, y: 0), on: store))
        store.state.updateTile(at: .init(x: 3, y: 9)) { $0.constructionProgress = 0.5 }
        XCTAssertFalse(CityUtilityExpenseSitesView.find(.init(x: 3, y: 9), on: store))
        store.state = original
        store.presentBlockingModal(.newRegionSetup)
        XCTAssertFalse(CityUtilityExpenseSitesView.find(.init(x: 3, y: 9), on: store))
        XCTAssertEqual(store.selectedCoordinate, selected)
        XCTAssertEqual(store.overlay, overlay)
        XCTAssertEqual(store.diagnosticFocusRequestGeneration, generation)
        XCTAssertEqual(store.state, original)
    }

    @MainActor
    func testFacilityComparisonFitsAndReadsAtBothSizes() throws {
        let expenses = CityOperatingExpensePresentation.make(in: district())
        for compact in [true, false] {
            let width = compact ? BuildToolbarView.compactDetailsWidth : BuildToolbarView.regularDetailsWidth
            let host = NSHostingView(rootView: CityUtilityExpenseSitesView(
                presentation: expenses, compact: compact, onBack: {}, onFind: { _ in })
                .preferredColorScheme(.dark).frame(width: width - 6))
            host.layoutSubtreeIfNeeded()
            host.frame.size = host.fittingSize
            settle(host)
            XCTAssertLessThanOrEqual(host.fittingSize.height + (compact ? 59 : 63),
                BuildToolbarView.detailsHeight(compact: compact, selectedBlock: false, finances: true))
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            try VNImageRequestHandler(cgImage: XCTUnwrap(bitmap.cgImage)).perform([request])
            let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ").lowercased()
            for expected in ["all expenses", "$519.75", "not demolition savings", "power plant", "water tower", "find", "block 4, 10", "block 5, 9"] {
                XCTAssertTrue(text.contains(expected), "compact=\(compact), missing \(expected): \(text)")
            }
        }
    }

    @MainActor
    func testFindRevealsReadableFacilityAndRetainsInspectionAtBothSizes() throws {
        for size in [CGSize(width: 900, height: 600), CGSize(width: 1280, height: 800)] {
            let store = CityGameStore(state: district(), startsPaused: true)
            let original = store.state
            var frames = CityHUDChromeFrames()
            let host = NSHostingView(rootView: ContentView(store: store) { frames = $0 }
                .transaction { $0.disablesAnimations = true }.frame(width: size.width, height: size.height))
            host.frame = CGRect(origin: .zero, size: size)
            settle(host)
            let map = try XCTUnwrap(findMap(in: host))
            let scene = try XCTUnwrap(map.scene as? CityScene)
            for coordinate in [GridCoordinate(x: 3, y: 9), .init(x: 4, y: 8)] {
                store.openInspector(.finances)
                settle(host)
                XCTAssertTrue(CityUtilityExpenseSitesView.find(coordinate, on: store))
                settle(host)
                let bounds = scene.inspectedPlaceBoundsForTesting(at: coordinate)
                let insets = ContentView.mapViewportInsets(windowSize: size,
                    compact: ContentView.isCompactLayout(size), chromeFrames: frames)
                XCTAssertTrue(frames.inspector.isEmpty)
                XCTAssertTrue(scene.inspectedPlaceViewportForTesting(insets).contains(bounds))
                XCTAssertGreaterThan(bounds.height / scene.cameraScaleForTesting, 120)
                XCTAssertTrue(map.cityAccessibilityValue.contains("block \(coordinate.x + 1), \(coordinate.y + 1)"))
                store.showSelectionContext()
                settle(host)
                XCTAssertEqual(store.selectedCoordinate, coordinate)
                XCTAssertTrue(store.showInspector)
                XCTAssertEqual(store.state, original)
                XCTAssertFalse(store.canUndo)
            }
        }
    }

    private func district() -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        state.updateTile(at: .init(x: 3, y: 9)) { $0.kind = .waterTower }
        state.updateTile(at: .init(x: 4, y: 8)) { $0.kind = .powerPlant }
        state.powerCapacity = 600
        state.waterCapacity = 540
        return state
    }

    @MainActor private func settle(_ host: NSView) {
        for _ in 0..<6 {
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        }
    }

    @MainActor private func findMap(in view: NSView) -> CityMapSKView? {
        if let map = view as? CityMapSKView { return map }
        return view.subviews.lazy.compactMap { self.findMap(in: $0) }.first
    }
}
