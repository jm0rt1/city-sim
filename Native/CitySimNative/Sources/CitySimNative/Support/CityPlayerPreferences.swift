import Foundation
import SwiftUI

enum CityPlayerPreferenceKey {
    static let soundEffects = "soundEffects"
    static let reduceMotion = "reduceGameMotion"
    static let reduceTransparency = "reduceGameTransparency"
    static let increaseContrast = "increaseGameContrast"
    static let differentiateWithoutColor = "differentiateGameWithoutColor"
    static let hasSeenWelcome = "hasSeenCitySimWelcome"
}

struct CityPlayerPreferenceSnapshot: Equatable, Sendable {
    let soundEffects: Bool
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let increaseContrast: Bool
    let differentiateWithoutColor: Bool

    static let standard = Self(
        soundEffects: true,
        reduceMotion: false,
        reduceTransparency: false,
        increaseContrast: false,
        differentiateWithoutColor: false
    )

    static func read(from defaults: UserDefaults) -> Self {
        Self(
            soundEffects: defaults.object(forKey: CityPlayerPreferenceKey.soundEffects) as? Bool ?? true,
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
