import SwiftUI

struct WelcomeView: View {
    let continueAction: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.66).ignoresSafeArea()
            VStack(spacing: 22) {
                ZStack {
                    Circle().fill(GameTheme.accent.opacity(0.16)).frame(width: 92, height: 92)
                    Image(systemName: "building.2.crop.circle.fill")
                        .font(.system(size: 50, weight: .semibold))
                        .foregroundStyle(GameTheme.accent.gradient)
                }
                VStack(spacing: 7) {
                    Text("Welcome to New Arcadia")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                    Text("Build a connected, solvent city that 2,500 residents are proud to call home.")
                        .font(.title3).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                HStack(alignment: .top, spacing: 28) {
                    tip("hammer.fill", "Build", "Choose a tool and click open land. Most buildings need a neighboring road.")
                    tip("waveform.path.ecg", "Balance", "Watch demand, utilities, happiness, jobs, and the city treasury.")
                    tip("map.fill", "Diagnose", "Use data overlays and the inspector to understand every block.")
                }
                .frame(maxWidth: 720)
                HStack {
                    Label("Space pauses · 1–3 set speed · ⌘Z undoes", systemImage: "keyboard")
                        .font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    Button("Start Building") { continueAction() }
                        .buttonStyle(.borderedProminent).controlSize(.large).tint(GameTheme.accent)
                        .keyboardShortcut(.defaultAction)
                        .accessibilityIdentifier("welcome.start-building")
                        .accessibilityHint("Dismisses Welcome and enables city commands at normal speed")
                }
            }
            .padding(34)
            .frame(width: 820)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.15)))
            .shadow(color: .black.opacity(0.45), radius: 36, y: 18)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Welcome to New Arcadia")
        }
        .accessibilityIdentifier("welcome.blocking-modal")
    }

    private func tip(_ symbol: String, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol).font(.title2).foregroundStyle(GameTheme.accent)
            Text(title).font(.headline)
            Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
