import AppKit
import Foundation
import SwiftUI
import XCTest
@testable import CitySimNative

final class NamedBranchTests: XCTestCase {
    func testServiceWritesImmutableNamedBranchAndReloadsItsMetadata() throws {
        let root = temporaryRoot(named: "service")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        var state = CityGameState.newCity(seed: 91)
        state.cityName = "Fork Harbor"
        state.tick = 44
        state.population = 512

        let write = try service.saveNamedBranch(state, name: "  Before Freight  ")

        XCTAssertEqual(service.branchURLs.count, 1)
        XCTAssertFalse(service.hasLoadCandidate)
        XCTAssertTrue(service.hasResumeCandidate)
        XCTAssertFalse(FileManager.default.fileExists(atPath: service.saveURL.path))
        XCTAssertTrue(service.autosaveURLs.allSatisfy {
            !FileManager.default.fileExists(atPath: $0.path)
        })
        let bytes = try Data(contentsOf: try XCTUnwrap(service.branchURLs.first))
        let catalog = service.checkpointCatalog()
        let branch = try XCTUnwrap(catalog.first)
        XCTAssertEqual(branch.source, .branch)
        XCTAssertEqual(branch.branchName, "Before Freight")
        XCTAssertEqual(branch.loadResult?.branchName, "Before Freight")
        XCTAssertEqual(branch.loadResult?.state, state)
        XCTAssertEqual(branch.loadResult?.fingerprint, write.fingerprint)

        let relaunched = SaveGameService(rootURL: root)
        XCTAssertEqual(relaunched.checkpointCatalog().first?.branchName, "Before Freight")
        XCTAssertEqual(try Data(contentsOf: try XCTUnwrap(relaunched.branchURLs.first)), bytes)

        XCTAssertThrowsError(try relaunched.saveNamedBranch(state, name: "before freight")) {
            XCTAssertEqual($0 as? SaveGameError, .duplicateBranchName("before freight"))
        }
        XCTAssertEqual(relaunched.branchURLs.count, 1)
        XCTAssertThrowsError(try relaunched.saveNamedBranch(state, name: "   ")) {
            XCTAssertEqual($0 as? SaveGameError, .invalidBranchName)
        }

        let invalidURL = service.branchDirectoryURL.appending(path: "branch-invalid.json")
        let invalidBytes = Data("broken branch".utf8)
        try invalidBytes.write(to: invalidURL, options: .atomic)
        let namesBefore = try FileManager.default.contentsOfDirectory(
            atPath: service.branchDirectoryURL.path
        ).sorted()
        let invalid = try XCTUnwrap(service.checkpointCatalog().first {
            $0.fileName == invalidURL.lastPathComponent
        })
        XCTAssertEqual(invalid.source, .branch)
        XCTAssertEqual(invalid.integrity, .invalid)
        XCTAssertFalse(invalid.isLoadable)
        XCTAssertNil(invalid.branchName)
        XCTAssertEqual(try Data(contentsOf: invalidURL), invalidBytes)
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(
                atPath: service.branchDirectoryURL.path
            ).sorted(),
            namesBefore
        )
    }

    @MainActor
    func testLiveCityBranchMarksExactStatePersistedAndKeepsPlaying() throws {
        let root = temporaryRoot(named: "live")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        var state = CityGameState.newCity(seed: 22)
        state.cityName = "Living Harbor"
        state.tick = 52
        state.population = 486
        let store = CityGameStore(state: state, saveService: service)
        store.setSpeed(.fastest)

        XCTAssertTrue(store.perform(.saveBranch))
        XCTAssertEqual(store.commandPolicy, .blocked(.branchNaming))
        XCTAssertEqual(store.speed, .paused)
        XCTAssertEqual(store.branchNaming?.sourceLabel, "Branch from current city")
        XCTAssertTrue(store.branchNameDraft.contains("Living Harbor"))

        store.updateBranchNameDraft("Before Downtown Expansion")
        XCTAssertTrue(store.createNamedBranch())

        XCTAssertEqual(store.state, state)
        XCTAssertEqual(store.speed, .fastest)
        XCTAssertEqual(store.commandPolicy, .enabled)
        XCTAssertNil(store.branchNaming)
        XCTAssertEqual(store.persistenceStatus.label, "Branched")
        XCTAssertFalse(store.hasUnsavedProgress)
        XCTAssertEqual(
            store.lastFeedback,
            "Timeline branch “Before Downtown Expansion” created · Day 14 · 486 residents"
        )
        XCTAssertEqual(service.checkpointCatalog().first?.loadResult?.state, state)

        store.state.tick += 1
        XCTAssertEqual(store.persistenceStatus.label, "Unsaved changes")
        XCTAssertTrue(store.hasUnsavedProgress)
    }

    @MainActor
    func testBranchFromAutosaveDoesNotLoadOrOverwriteEitherTimeline() throws {
        let root = temporaryRoot(named: "autosave")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        var autosave = CityGameState.newCity(seed: 33)
        autosave.cityName = "Earlier Harbor"
        autosave.tick = 28
        autosave.population = 404
        try service.saveAutosave(autosave)
        let autosaveBytes = try Data(contentsOf: service.autosaveURLs[0])

        var current = CityGameState.newCity(seed: 44)
        current.cityName = "Current Harbor"
        current.tick = 72
        current.population = 620
        let currentFingerprint = try CityStateFingerprinter.fingerprint(current)
        let store = CityGameStore(state: current, saveService: service)
        store.setSpeed(.fastest)

        XCTAssertTrue(store.perform(.loadCity))
        let autosaveID = try XCTUnwrap(store.checkpointLibrary?.cards.first?.id)
        XCTAssertTrue(store.beginBranchNaming(for: autosaveID))
        XCTAssertEqual(store.commandPolicy, .blocked(.branchNaming))
        XCTAssertEqual(store.branchNaming?.sourceLabel, "Branch from rotating autosave")
        XCTAssertNil(store.checkpointLibrary)

        store.updateBranchNameDraft("Before the Budget Shock")
        XCTAssertTrue(store.createNamedBranch())

        XCTAssertEqual(try CityStateFingerprinter.fingerprint(store.state), currentFingerprint)
        XCTAssertEqual(store.speed, .fastest)
        XCTAssertNil(store.sessionReplacementConfirmation)
        XCTAssertEqual(try Data(contentsOf: service.autosaveURLs[0]), autosaveBytes)
        let branch = try XCTUnwrap(service.checkpointCatalog().first {
            $0.source == .branch
        })
        XCTAssertEqual(branch.branchName, "Before the Budget Shock")
        XCTAssertEqual(branch.loadResult?.state, autosave)

        XCTAssertTrue(store.perform(.loadCity))
        let branchCard = try XCTUnwrap(store.checkpointLibrary?.cards.first {
            $0.sourceLabel == "Named timeline branch"
        })
        XCTAssertEqual(branchCard.title, "Before the Budget Shock")
        XCTAssertTrue(branchCard.checkpoint.contains("Earlier Harbor"))
        XCTAssertTrue(branchCard.canBranch)
        XCTAssertTrue(store.cancelCheckpointLibrary())
    }

    @MainActor
    func testDuplicateNameStaysEditableAndCancelReturnsToCheckpointLibrary() throws {
        let root = temporaryRoot(named: "duplicate")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        var saved = CityGameState.newCity(seed: 55)
        saved.cityName = "Choice Harbor"
        saved.tick = 20
        try service.saveAutosave(saved)
        try service.saveNamedBranch(saved, name: "Safe Choice")
        let store = CityGameStore(state: .newCity(seed: 66), saveService: service)
        store.setSpeed(.fast)

        XCTAssertTrue(store.perform(.loadCity))
        let autosaveID = try XCTUnwrap(store.checkpointLibrary?.cards.first {
            $0.sourceLabel == "Rotating autosave"
        }?.id)
        XCTAssertTrue(store.beginBranchNaming(for: autosaveID))
        store.updateBranchNameDraft("safe choice")
        XCTAssertFalse(store.createNamedBranch())
        XCTAssertEqual(
            store.branchNameError,
            "A timeline branch named safe choice already exists."
        )
        XCTAssertEqual(store.commandPolicy, .blocked(.branchNaming))
        XCTAssertEqual(service.branchURLs.count, 1)

        XCTAssertTrue(store.cancelBranchNaming())
        XCTAssertEqual(store.commandPolicy, .blocked(.checkpointLibrary))
        XCTAssertNotNil(store.checkpointLibrary)
        XCTAssertEqual(store.speed, .paused)
        XCTAssertTrue(store.cancelCheckpointLibrary())
        XCTAssertEqual(store.speed, .fast)
        XCTAssertEqual(store.state, .newCity(seed: 66))
    }

    @MainActor
    func testBranchOnlyStartupOfferResumesNamedTimelinePaused() throws {
        let root = temporaryRoot(named: "startup")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        var saved = CityGameState.newCity(seed: 77)
        saved.cityName = "Branch Harbor"
        saved.tick = 36
        saved.population = 455
        try service.saveNamedBranch(saved, name: "The Recovery Plan")
        let store = CityGameStore(saveService: service)

        store.prepareStartupResumeOffer()

        XCTAssertEqual(store.startupResumeOffer?.sourceLabel, "Named branch · The Recovery Plan")
        XCTAssertEqual(store.startupResumeOffer?.sourceSymbol, "arrow.triangle.branch")
        XCTAssertTrue(store.resumeStartupCity())
        XCTAssertEqual(store.state, saved)
        XCTAssertEqual(store.speed, .paused)
        XCTAssertEqual(store.persistenceStatus.label, "Branched")
        XCTAssertEqual(
            store.lastFeedback,
            "Resumed “The Recovery Plan” · Day 10 · 455 residents · Simulation paused"
        )
    }

    @MainActor
    func testBranchNamingRendersAtCompactAndDefaultWindowSizes() throws {
        var state = CityGameState.newCity(seed: 88)
        state.cityName = "Timeline Harbor"
        state.tick = 44
        state.population = 512
        let presentation = CityBranchNamingPresentation.make(state: state, source: .autosave)

        for size in [CGSize(width: 900, height: 600), CGSize(width: 1_280, height: 800)] {
            let image = try bitmap(
                of: BranchNamingView(
                    presentation: presentation,
                    name: "Before the Freight Expansion",
                    error: nil,
                    canCreate: true,
                    updateName: { _ in },
                    createAction: {},
                    cancelAction: {}
                ).frame(width: size.width, height: size.height),
                size: size
            )
            XCTAssertEqual(image.size.width, size.width, accuracy: 0.5)
            XCTAssertEqual(image.size.height, size.height, accuracy: 0.5)
            if size.width > 1_000,
               let path = ProcessInfo.processInfo.environment["CITYSIM_BRANCH_NAMING_PROOF"] {
                let data = try XCTUnwrap(image.representation(using: .png, properties: [:]))
                try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            }
        }
    }

    private func temporaryRoot(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "citysim-branch-\(name)-\(UUID().uuidString)", directoryHint: .isDirectory)
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
