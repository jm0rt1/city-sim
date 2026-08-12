import SwiftUI

struct StartupResumeView: View {
    let presentation: CityStartupResumePresentation
    let resumeAction: () -> Void
    let startFreshAction: () -> Void
    @FocusState private var resumeHasKeyboardFocus: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.66).ignoresSafeArea()
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(GameTheme.accent.opacity(0.16))
                        .frame(width: 78, height: 78)
                    Image(systemName: presentation.sourceSymbol)
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(GameTheme.accent.gradient)
                }
                VStack(spacing: 8) {
                    Text(presentation.title)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                    Text(presentation.checkpoint)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                    Label(presentation.sourceLabel, systemImage: presentation.sourceSymbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(GameTheme.accent)
                    Text(presentation.detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 12) {
                    Button(presentation.startFreshActionTitle, action: startFreshAction)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .accessibilityIdentifier("startup-resume.start-fresh")
                        .accessibilityHint("Keeps the saved city available from Load City")
                    Button(presentation.resumeActionTitle, action: resumeAction)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(GameTheme.accent)
                        .keyboardShortcut(.defaultAction)
                        .focused($resumeHasKeyboardFocus)
                        .accessibilityIdentifier("startup-resume.resume")
                        .accessibilityHint("Loads the verified checkpoint and keeps the simulation paused")
                }
            }
            .padding(32)
            .frame(width: 680)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.15)))
            .shadow(color: .black.opacity(0.45), radius: 36, y: 18)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(presentation.accessibilitySummary)
        }
        .onAppear { resumeHasKeyboardFocus = true }
        .accessibilityIdentifier("startup-resume.blocking-modal")
    }
}
