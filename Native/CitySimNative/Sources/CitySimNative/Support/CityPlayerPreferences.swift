import Foundation
import SwiftUI

enum CityPlayerPreferenceKey {
    static let soundEffects = "soundEffects"
    static let effectsVolume = "effectsVolume"
    static let reduceMotion = "reduceGameMotion"
    static let reduceTransparency = "reduceGameTransparency"
    static let increaseContrast = "increaseGameContrast"
    static let differentiateWithoutColor = "differentiateGameWithoutColor"
    static let hasSeenWelcome = "hasSeenCitySimWelcome"
    static let foundationsGuideProgress = "cityFoundationsGuideProgress.v1"
    static let foundationsGuideRevision = "cityFoundationsGuideRevision"
}

struct CityPlayerPreferenceSnapshot: Equatable, Sendable {
    let soundEffects: Bool
    let effectsVolume: Double
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let increaseContrast: Bool
    let differentiateWithoutColor: Bool

    static let standard = Self(
        soundEffects: true,
        effectsVolume: 0.75,
        reduceMotion: false,
        reduceTransparency: false,
        increaseContrast: false,
        differentiateWithoutColor: false
    )

    init(
        soundEffects: Bool,
        effectsVolume: Double = 0.75,
        reduceMotion: Bool,
        reduceTransparency: Bool,
        increaseContrast: Bool,
        differentiateWithoutColor: Bool
    ) {
        self.soundEffects = soundEffects
        self.effectsVolume = min(1, max(0, effectsVolume))
        self.reduceMotion = reduceMotion
        self.reduceTransparency = reduceTransparency
        self.increaseContrast = increaseContrast
        self.differentiateWithoutColor = differentiateWithoutColor
    }

    static func read(from defaults: UserDefaults) -> Self {
        Self(
            soundEffects: defaults.object(forKey: CityPlayerPreferenceKey.soundEffects) as? Bool ?? true,
            effectsVolume: defaults.object(forKey: CityPlayerPreferenceKey.effectsVolume) as? Double
                ?? Self.standard.effectsVolume,
            reduceMotion: defaults.bool(forKey: CityPlayerPreferenceKey.reduceMotion),
            reduceTransparency: defaults.bool(forKey: CityPlayerPreferenceKey.reduceTransparency),
            increaseContrast: defaults.bool(forKey: CityPlayerPreferenceKey.increaseContrast),
            differentiateWithoutColor: defaults.bool(
                forKey: CityPlayerPreferenceKey.differentiateWithoutColor
            )
        )
    }

    func write(to defaults: UserDefaults) {
        defaults.set(soundEffects, forKey: CityPlayerPreferenceKey.soundEffects)
        defaults.set(effectsVolume, forKey: CityPlayerPreferenceKey.effectsVolume)
        defaults.set(reduceMotion, forKey: CityPlayerPreferenceKey.reduceMotion)
        defaults.set(reduceTransparency, forKey: CityPlayerPreferenceKey.reduceTransparency)
        defaults.set(increaseContrast, forKey: CityPlayerPreferenceKey.increaseContrast)
        defaults.set(
            differentiateWithoutColor,
            forKey: CityPlayerPreferenceKey.differentiateWithoutColor
        )
    }

    static func resolved(playerOverride: Bool, systemPreference: Bool) -> Bool {
        playerOverride || systemPreference
    }
}

enum CitySettingsActions {
    static func showWelcomeAgain(in defaults: UserDefaults) {
        defaults.set(false, forKey: CityPlayerPreferenceKey.hasSeenWelcome)
    }

    static func restorePreferenceDefaults(in defaults: UserDefaults) {
        CityPlayerPreferenceSnapshot.standard.write(to: defaults)
    }

    static func restartFoundationsGuide(in defaults: UserDefaults) {
        CityFoundationsGuidePersistence.reset(in: defaults)
        defaults.set(
            defaults.integer(forKey: CityPlayerPreferenceKey.foundationsGuideRevision) + 1,
            forKey: CityPlayerPreferenceKey.foundationsGuideRevision
        )
    }
}

struct CityAccessibilityAppearance: Equatable, Sendable {
    let reduceTransparency: Bool
    let increaseContrast: Bool
    let differentiateWithoutColor: Bool

    static let standard = Self(
        reduceTransparency: false,
        increaseContrast: false,
        differentiateWithoutColor: false
    )
}

private struct CityAccessibilityAppearanceKey: EnvironmentKey {
    static let defaultValue = CityAccessibilityAppearance.standard
}

extension EnvironmentValues {
    var cityAccessibilityAppearance: CityAccessibilityAppearance {
        get { self[CityAccessibilityAppearanceKey.self] }
        set { self[CityAccessibilityAppearanceKey.self] = newValue }
    }
}

private struct CityAccessibilityAppearanceModifier: ViewModifier {
    let appearance: CityAccessibilityAppearance

    func body(content: Content) -> some View {
        content
            .environment(\.cityAccessibilityAppearance, appearance)
    }
}

private struct CityPanelBackgroundModifier<PanelShape: Shape>: ViewModifier {
    @Environment(\.cityAccessibilityAppearance) private var appearance
    let material: Material
    let shape: PanelShape

    func body(content: Content) -> some View {
        content.background(
            appearance.reduceTransparency
                ? AnyShapeStyle(GameTheme.opaquePanel)
                : AnyShapeStyle(material),
            in: shape
        )
        .contrast(appearance.increaseContrast ? 1.12 : 1)
        .saturation(appearance.differentiateWithoutColor ? 0.68 : 1)
    }
}

extension View {
    func cityAccessibilityAppearance(_ appearance: CityAccessibilityAppearance) -> some View {
        modifier(CityAccessibilityAppearanceModifier(appearance: appearance))
    }

    func cityPanelBackground<PanelShape: Shape>(
        _ material: Material,
        in shape: PanelShape
    ) -> some View {
        modifier(CityPanelBackgroundModifier(material: material, shape: shape))
    }
}
