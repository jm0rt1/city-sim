import AppKit
import SwiftUI
import XCTest
@testable import CitySimNative

final class CitySettingsTests: XCTestCase {
    @MainActor
    func testCityCoachRestartCopyUsesThePlayerFacingProductName() {
        XCTAssertEqual(SettingsView.restartCityCoachTitle, "Restart City Coach")
        XCTAssertEqual(
            SettingsView.cityCoachRestartedFeedback,
            "City Coach restarted in the main city window."
        )
    }

    func testPreferenceDefaultsAndPersistedOverridesAreTruthful() throws {
        let defaults = try isolatedDefaults()

        XCTAssertEqual(CityPlayerPreferenceSnapshot.read(from: defaults), .standard)

        let chosen = CityPlayerPreferenceSnapshot(
            soundEffects: false,
            effectsVolume: 0.4,
            reduceMotion: true,
            reduceTransparency: true,
            increaseContrast: true,
            differentiateWithoutColor: true
        )
        chosen.write(to: defaults)

        XCTAssertEqual(CityPlayerPreferenceSnapshot.read(from: defaults), chosen)
        XCTAssertEqual(CityPlayerPreferenceSnapshot.read(from: defaults).effectsVolume, 0.4)
    }

    func testPlayerAppearanceOverridesAddToRatherThanEraseSystemPreferences() {
        XCTAssertFalse(CityPlayerPreferenceSnapshot.resolved(
            playerOverride: false,
            systemPreference: false
        ))
        XCTAssertTrue(CityPlayerPreferenceSnapshot.resolved(
            playerOverride: true,
            systemPreference: false
        ))
        XCTAssertTrue(CityPlayerPreferenceSnapshot.resolved(
            playerOverride: false,
            systemPreference: true
        ))
        XCTAssertTrue(CityPlayerPreferenceSnapshot.resolved(
            playerOverride: true,
            systemPreference: true
        ))
    }

    func testShowingWelcomeAgainPreservesEveryPreferenceAndCurrentSaveDomain() throws {
        let defaults = try isolatedDefaults()
        let chosen = CityPlayerPreferenceSnapshot(
            soundEffects: false,
            reduceMotion: true,
            reduceTransparency: true,
            increaseContrast: false,
            differentiateWithoutColor: true
        )
        chosen.write(to: defaults)
        defaults.set(true, forKey: CityPlayerPreferenceKey.hasSeenWelcome)
        defaults.set("preserved", forKey: "unrelated-save-domain-sentinel")

        CitySettingsActions.showWelcomeAgain(in: defaults)

        XCTAssertFalse(defaults.bool(forKey: CityPlayerPreferenceKey.hasSeenWelcome))
        XCTAssertEqual(CityPlayerPreferenceSnapshot.read(from: defaults), chosen)
        XCTAssertEqual(defaults.string(forKey: "unrelated-save-domain-sentinel"), "preserved")
    }

    func testRestoreDefaultsDoesNotResetWelcomeOrUnrelatedPlayerData() throws {
        let defaults = try isolatedDefaults()
        CityPlayerPreferenceSnapshot(
            soundEffects: false,
            reduceMotion: true,
            reduceTransparency: true,
            increaseContrast: true,
            differentiateWithoutColor: true
        ).write(to: defaults)
        defaults.set(true, forKey: CityPlayerPreferenceKey.hasSeenWelcome)
        defaults.set(42, forKey: "unrelated-player-data")

        CitySettingsActions.restorePreferenceDefaults(in: defaults)

        XCTAssertEqual(CityPlayerPreferenceSnapshot.read(from: defaults), .standard)
        XCTAssertTrue(defaults.bool(forKey: CityPlayerPreferenceKey.hasSeenWelcome))
        XCTAssertEqual(defaults.integer(forKey: "unrelated-player-data"), 42)
    }

    @MainActor
    func testShowingWelcomeAgainUpdatesTheLiveCityWithoutMutatingIt() throws {
        let defaults = UserDefaults.standard
        let key = CityPlayerPreferenceKey.hasSeenWelcome
        let priorWelcome = defaults.object(forKey: key)
        defaults.set(true, forKey: key)
        defer {
            if let priorWelcome {
                defaults.set(priorWelcome, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        var progressed = CityGameState.newCity(seed: 1_301)
        progressed.tick = 12
        progressed.treasury -= 250
        let store = CityGameStore(state: progressed, startsPaused: true)
        let size = CGSize(width: 900, height: 600)
        let host = NSHostingView(
            rootView: ContentView(store: store)
                .frame(width: size.width, height: size.height)
        )
        host.frame = CGRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))
        let state = store.state
        let speed = store.speed

        CitySettingsActions.showWelcomeAgain(in: defaults)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))

        XCTAssertEqual(store.commandPolicy, .blocked(.welcome))
        XCTAssertEqual(store.state, state)
        XCTAssertEqual(store.speed, speed)
    }

    @MainActor
    func testWelcomeReplayQueuesBehindAProtectedRecoveryJourney() throws {
        let defaults = UserDefaults.standard
        let key = CityPlayerPreferenceKey.hasSeenWelcome
        let priorWelcome = defaults.object(forKey: key)
        defaults.set(true, forKey: key)
        defer {
            if let priorWelcome {
                defaults.set(priorWelcome, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        let store = CityGameStore(
            state: .newCity(seed: 1_302),
            commandPolicy: .blocked(.checkpointLibrary),
            startsPaused: true
        )
        let size = CGSize(width: 900, height: 600)
        let host = NSHostingView(
            rootView: ContentView(store: store)
                .frame(width: size.width, height: size.height)
        )
        host.frame = CGRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))

        CitySettingsActions.showWelcomeAgain(in: defaults)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        XCTAssertEqual(store.commandPolicy, .blocked(.checkpointLibrary))

        XCTAssertTrue(store.dismissBlockingModal(.checkpointLibrary))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        XCTAssertEqual(store.commandPolicy, .blocked(.welcome))
    }

    @MainActor
    func testSettingsRenderWithAccessiblePreferencesAtNativeWindowSize() throws {
        let defaults = try isolatedDefaults()
        CityPlayerPreferenceSnapshot(
            soundEffects: true,
            reduceMotion: true,
            reduceTransparency: true,
            increaseContrast: true,
            differentiateWithoutColor: true
        ).write(to: defaults)
        defaults.set(true, forKey: CityPlayerPreferenceKey.hasSeenWelcome)
        let size = CGSize(width: 540, height: 620)
        let image = try bitmap(
            of: SettingsView(defaults: defaults)
                .frame(width: size.width, height: size.height),
            size: size
        )

        XCTAssertEqual(image.size.width, size.width, accuracy: 0.5)
        XCTAssertEqual(image.size.height, size.height, accuracy: 0.5)
        XCTAssertGreaterThan(try opaquePixelRatio(in: image), 0.95)

        if let path = ProcessInfo.processInfo.environment["CITYSIM_SETTINGS_PROOF"] {
            let data = try XCTUnwrap(image.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }

    @MainActor
    func testAppearancePreferencesProduceDistinctOpaquePanelRendering() throws {
        let size = CGSize(width: 260, height: 120)
        let panel = Text("Treasury warning · $1,240")
            .font(.headline)
            .padding(18)
            .cityPanelBackground(
                .thin,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .frame(width: size.width, height: size.height)
        let standard = try bitmap(
            of: panel.cityAccessibilityAppearance(.standard),
            size: size
        )
        let accessible = try bitmap(
            of: panel.cityAccessibilityAppearance(
                CityAccessibilityAppearance(
                    reduceTransparency: true,
                    increaseContrast: true,
                    differentiateWithoutColor: true
                )
            ),
            size: size
        )

        XCTAssertNotEqual(
            standard.representation(using: .png, properties: [:]),
            accessible.representation(using: .png, properties: [:])
        )
    }

    private func isolatedDefaults() throws -> UserDefaults {
        let suite = "CitySettingsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        addTeardownBlock {
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        }
        return defaults
    }

    @MainActor
    private func bitmap<Content: View>(of content: Content, size: CGSize) throws -> NSBitmapImageRep {
        let view = NSHostingView(rootView: content)
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))
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
