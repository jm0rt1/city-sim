import SwiftUI

struct SettingsView: View {
    @AppStorage private var soundEffects: Bool
    @AppStorage private var reduceMotion: Bool
    @AppStorage private var reduceTransparency: Bool
    @AppStorage private var increaseContrast: Bool
    @AppStorage private var differentiateWithoutColor: Bool
    @AppStorage private var hasSeenWelcome: Bool
    @State private var guidanceFeedback: String?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        _soundEffects = AppStorage(
            wrappedValue: true,
            CityPlayerPreferenceKey.soundEffects,
            store: defaults
        )
        _reduceMotion = AppStorage(
            wrappedValue: false,
            CityPlayerPreferenceKey.reduceMotion,
            store: defaults
        )
        _reduceTransparency = AppStorage(
            wrappedValue: false,
            CityPlayerPreferenceKey.reduceTransparency,
            store: defaults
        )
        _increaseContrast = AppStorage(
            wrappedValue: false,
            CityPlayerPreferenceKey.increaseContrast,
            store: defaults
        )
        _differentiateWithoutColor = AppStorage(
            wrappedValue: false,
            CityPlayerPreferenceKey.differentiateWithoutColor,
            store: defaults
        )
        _hasSeenWelcome = AppStorage(
            wrappedValue: false,
            CityPlayerPreferenceKey.hasSeenWelcome,
            store: defaults
        )
    }

    var body: some View {
        Form {
            Section("Audio") {
                preferenceToggle(
                    "Sound effects",
                    detail: "Confirm construction, saves, and important city actions.",
                    symbol: "speaker.wave.2.fill",
                    isOn: $soundEffects
                )
                .accessibilityIdentifier("settings.sound-effects")
            }

            Section("Motion") {
                preferenceToggle(
                    "Reduce ambient animation",
                    detail: "Softens nonessential movement while keeping city state current.",
                    symbol: "figure.walk.motion",
                    isOn: $reduceMotion
                )
                .accessibilityIdentifier("settings.reduce-motion")
            }

            Section("Accessible Appearance") {
                preferenceToggle(
                    "Reduce transparency",
                    detail: "Uses more opaque native materials for stronger panel separation.",
                    symbol: "square.on.square",
                    isOn: $reduceTransparency
                )
                .accessibilityIdentifier("settings.reduce-transparency")

                preferenceToggle(
                    "Increase contrast",
                    detail: "Strengthens native control and text contrast throughout the game window.",
                    symbol: "circle.lefthalf.filled",
                    isOn: $increaseContrast
                )
                .accessibilityIdentifier("settings.increase-contrast")

                preferenceToggle(
                    "Color-independent cues",
                    detail: "Reduces color intensity so existing symbols, labels, and values carry more distinction.",
                    symbol: "eye.trianglebadge.exclamationmark.fill",
                    isOn: $differentiateWithoutColor
                )
                .accessibilityIdentifier("settings.differentiate-without-color")
            }

            Section("Guidance") {
                LabeledContent {
                    Button("Show Welcome Again") {
                        CitySettingsActions.showWelcomeAgain(in: defaults)
                        hasSeenWelcome = false
                        guidanceFeedback = "Welcome is ready in the main city window."
                    }
                    .disabled(!hasSeenWelcome)
                    .accessibilityHint("Reopens first-run guidance without changing the current city")
                    .accessibilityIdentifier("settings.show-welcome-again")
                } label: {
                    Label("First-run city guidance", systemImage: "sparkles.rectangle.stack.fill")
                }

                Text(
                    guidanceFeedback
                        ?? (hasSeenWelcome
                            ? "You can replay Welcome without resetting or replacing the current city."
                            : "Welcome is currently active in the main city window.")
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("settings.guidance-status")

                HStack {
                    Spacer()
                    Button("Restore Preference Defaults") {
                        CitySettingsActions.restorePreferenceDefaults(in: defaults)
                        let restored = CityPlayerPreferenceSnapshot.standard
                        soundEffects = restored.soundEffects
                        reduceMotion = restored.reduceMotion
                        reduceTransparency = restored.reduceTransparency
                        increaseContrast = restored.increaseContrast
                        differentiateWithoutColor = restored.differentiateWithoutColor
                    }
                    .accessibilityHint("Restores audio, motion, and appearance settings only")
                    .accessibilityIdentifier("settings.restore-defaults")
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(reduceTransparency ? GameTheme.opaquePanel : GameTheme.hudSurfaceFill)
        .frame(width: 540, height: 620)
        .cityAccessibilityAppearance(
            CityAccessibilityAppearance(
                reduceTransparency: reduceTransparency,
                increaseContrast: increaseContrast,
                differentiateWithoutColor: differentiateWithoutColor
            )
        )
        .contrast(increaseContrast ? 1.12 : 1)
        .saturation(differentiateWithoutColor ? 0.68 : 1)
        .accessibilityIdentifier("city-settings")
    }

    private func preferenceToggle(
        _ title: String,
        detail: String,
        symbol: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            Label {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: symbol)
                    .foregroundStyle(GameTheme.information)
            }
        }
        .toggleStyle(.switch)
        .accessibilityLabel(title)
        .accessibilityHint(detail)
    }
}
