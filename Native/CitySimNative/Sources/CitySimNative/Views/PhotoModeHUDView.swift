import SwiftUI

struct PhotoModeHUDView: View {
    @ObservedObject var store: CityGameStore
    let compact: Bool

    var body: some View {
        VStack {
            HStack(spacing: 8) {
                Label("PHOTO MODE", systemImage: "camera.aperture")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(GameTheme.accent)
                Text("\(store.state.cityName) · \(store.state.formattedDay)")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 8)
                if !compact {
                    Label("+ / − zoom · 0 frame", systemImage: "viewfinder")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Button {
                    store.perform(.capturePhoto)
                } label: {
                    Label("Capture PNG", systemImage: "camera.fill")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
                .accessibilityHint("Exports only the city composition without Photo Mode controls")
                Button {
                    store.perform(.togglePhotoMode)
                } label: {
                    Label(compact ? "Done" : "Exit Photo Mode", systemImage: "xmark")
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Restores the simulation speed from before Photo Mode")
            }
            .padding(8)
            .cityPanelBackground(.thin, in: Capsule())
            .shadow(color: .black.opacity(0.28), radius: 12, y: 5)

            Spacer()

            if let feedback = store.lastFeedback {
                Label(
                    feedback,
                    systemImage: store.lastFeedbackTone == .caution
                        ? "exclamationmark.triangle.fill"
                        : "checkmark.circle.fill"
                )
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .cityPanelBackground(.thin, in: Capsule())
                    .foregroundStyle(
                        store.lastFeedbackTone == .caution ? GameTheme.warning : GameTheme.accent
                    )
                    .accessibilityLabel("Photo Mode update")
                    .accessibilityValue(feedback)
            }
        }
        .padding(compact ? GameTheme.compactPadding : 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("photo-mode.controls")
    }
}
