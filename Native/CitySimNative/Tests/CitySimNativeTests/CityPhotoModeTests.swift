import AppKit
import SpriteKit
import SwiftUI
import XCTest
@testable import CitySimNative

final class CityPhotoModeTests: XCTestCase {
    func testPhotoServiceUsesSafeNonDestructiveNames() throws {
        let root = temporaryDirectory()
        let service = CityPhotoService(photoDirectoryURL: root.appending(path: "photos"))
        let data = Data([0x89, 0x50, 0x4E, 0x47])

        let first = try service.export(pngData: data, cityName: "  New Arcadia / East  ", day: 7)
        let second = try service.export(pngData: data, cityName: "  New Arcadia / East  ", day: 7)

        XCTAssertEqual(first.url.lastPathComponent, "New-Arcadia-East-Day-7.png")
        XCTAssertEqual(second.url.lastPathComponent, "New-Arcadia-East-Day-7-2.png")
        XCTAssertEqual(try Data(contentsOf: first.url), data)
        XCTAssertEqual(first.byteCount, data.count)
        XCTAssertThrowsError(try service.export(pngData: Data(), cityName: "City", day: 1)) {
            XCTAssertEqual($0 as? CityPhotoExportError, .emptyImage)
        }
    }

    @MainActor
    func testPhotoModePausesAndRestoresTheExactPlayerContext() {
        let store = CityGameStore(state: .newCity(seed: 42))
        store.speed = .fastest
        store.overlay = .traffic
        store.openInspector(.finances)
        let stateBefore = store.state

        XCTAssertTrue(store.perform(.togglePhotoMode))
        XCTAssertTrue(store.isPhotoModeEnabled)
        XCTAssertEqual(store.speed, .paused)
        XCTAssertEqual(store.overlay, .none)
        XCTAssertFalse(store.showInspector)
        XCTAssertEqual(store.state, stateBefore)
        XCTAssertTrue(store.canPerform(.capturePhoto))
        XCTAssertFalse(store.canPerform(.saveCity))
        XCTAssertFalse(store.canRouteMapCommand(.mapPrimaryAction))

        let generation = store.photoCaptureRequestGeneration
        XCTAssertTrue(store.perform(.capturePhoto))
        XCTAssertEqual(store.photoCaptureRequestGeneration, generation + 1)
        XCTAssertTrue(store.perform(.cancelInteraction))

        XCTAssertFalse(store.isPhotoModeEnabled)
        XCTAssertEqual(store.speed, .fastest)
        XCTAssertEqual(store.overlay, .traffic)
        XCTAssertTrue(store.showInspector)
        XCTAssertEqual(store.inspectorSection, .finances)
        XCTAssertEqual(store.state, stateBefore)
    }

    @MainActor
    func testPhotoModeRestoresPausedFocusCityWithoutAdvancingState() {
        let store = CityGameStore(state: .newCity(seed: 17), startsPaused: true)
        XCTAssertTrue(store.perform(.toggleCityFocus))
        let stateBefore = store.state

        store.enterPhotoMode()
        XCTAssertTrue(store.isPhotoModeEnabled)
        XCTAssertFalse(store.isCityFocusModeEnabled)
        store.exitPhotoMode()

        XCTAssertEqual(store.speed, .paused)
        XCTAssertTrue(store.isCityFocusModeEnabled)
        XCTAssertEqual(store.state, stateBefore)
    }

    func testPhotoCommandsAreDiscoverableAndDoNotCollide() {
        let mode = CityCommandCatalog.descriptor(for: .togglePhotoMode)
        let capture = CityCommandCatalog.descriptor(for: .capturePhoto)

        XCTAssertEqual(mode.shortcut?.display, "⇧⌘P")
        XCTAssertEqual(capture.shortcut?.display, "⇧⌘C")
        XCTAssertEqual(
            CityCommandCatalog.matchingCommand(
                key: "p",
                modifiers: [.command, .shift],
                scope: .global
            ),
            .togglePhotoMode
        )
        XCTAssertEqual(
            Set(CityCommandCatalog.matchingDescriptors(query: "photo").map(\.id)),
            Set([.togglePhotoMode, .capturePhoto])
        )
    }

    @MainActor
    func testLiveRendererCaptureExportsAHUDlessPNG() throws {
        let root = temporaryDirectory()
        let store = CityGameStore(
            state: .newCity(seed: 42),
            startsPaused: true,
            photoService: CityPhotoService(photoDirectoryURL: root.appending(path: "photos"))
        )
        store.enterPhotoMode()

        let size = CGSize(width: 900, height: 600)
        let view = CityMapSKView(frame: CGRect(origin: .zero, size: size))
        let scene = CityScene(size: size)
        view.presentScene(scene)
        scene.render(
            state: store.state,
            overlay: .none,
            selection: nil,
            selectedTool: .road,
            bulldozeMode: false
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))

        let coordinator = CitySceneView.Coordinator(store: store)
        coordinator.scene = scene
        let stateBeforeCapture = store.state
        store.requestPhotoCapture()
        XCTAssertTrue(
            coordinator.synchronizePhotoCaptureRequest(
                store.photoCaptureRequestGeneration,
                in: view
            )
        )

        let url = try XCTUnwrap(store.latestPhotoCaptureURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(store.state, stateBeforeCapture)
        let image = try XCTUnwrap(NSImage(contentsOf: url))
        XCTAssertGreaterThan(image.size.width, 600)
        XCTAssertGreaterThan(image.size.height, 400)
        XCTAssertEqual(
            url.deletingLastPathComponent().standardizedFileURL.path,
            root.appending(path: "photos", directoryHint: .isDirectory).standardizedFileURL.path
        )
        XCTAssertTrue(store.lastFeedback?.contains(url.lastPathComponent) == true)
        if let path = ProcessInfo.processInfo.environment["CITYSIM_PHOTO_CAPTURE_PROOF"] {
            try Data(contentsOf: url).write(
                to: URL(fileURLWithPath: path),
                options: .atomic
            )
        }
    }

    @MainActor
    func testPhotoModeControlsRenderAtMinimumWindowSize() throws {
        let defaults = try isolatedDefaults()
        defaults.set(true, forKey: CityPlayerPreferenceKey.hasSeenWelcome)
        defaults.set(true, forKey: CityPlayerPreferenceKey.reduceMotion)
        let store = CityGameStore(state: .newCity(seed: 42), startsPaused: true)
        store.enterPhotoMode()
        let size = CGSize(width: 900, height: 600)
        let cityImage = try renderedCityImage(size: size, state: store.state)
        let image = try bitmap(
            of: ZStack {
                Image(nsImage: cityImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                PhotoModeHUDView(store: store, compact: true)
                    .defaultAppStorage(defaults)
            }
            .clipped()
            .frame(width: size.width, height: size.height),
            size: size
        )

        XCTAssertEqual(image.size.width, 900, accuracy: 0.5)
        XCTAssertEqual(image.size.height, 600, accuracy: 0.5)
        XCTAssertGreaterThan(try opaquePixelRatio(in: image), 0.95)

        if let path = ProcessInfo.processInfo.environment["CITYSIM_PHOTO_MODE_PROOF"] {
            let data = try XCTUnwrap(image.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "CityPhotoModeTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func isolatedDefaults() throws -> UserDefaults {
        let suite = "CityPhotoModeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        addTeardownBlock {
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        }
        return defaults
    }

    @MainActor
    private func renderedCityImage(size: CGSize, state: CityGameState) throws -> NSImage {
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        let scene = CityScene(size: size)
        view.presentScene(scene)
        scene.render(
            state: state,
            overlay: .none,
            selection: nil,
            selectedTool: .road,
            bulldozeMode: false
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))
        let texture = try XCTUnwrap(view.texture(from: scene))
        return NSImage(cgImage: texture.cgImage(), size: size)
    }

    @MainActor
    private func bitmap<Content: View>(of content: Content, size: CGSize) throws -> NSBitmapImageRep {
        let view = NSHostingView(rootView: content)
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.35))
        let representation = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: representation)
        return representation
    }

    private func opaquePixelRatio(in image: NSBitmapImageRep) throws -> Double {
        guard image.pixelsWide > 0, image.pixelsHigh > 0 else { return 0 }
        var opaque = 0
        var sampled = 0
        for y in stride(from: 0, to: image.pixelsHigh, by: 8) {
            for x in stride(from: 0, to: image.pixelsWide, by: 8) {
                sampled += 1
                if let color = image.colorAt(x: x, y: y), color.alphaComponent > 0.01 {
                    opaque += 1
                }
            }
        }
        return Double(opaque) / Double(sampled)
    }
}
