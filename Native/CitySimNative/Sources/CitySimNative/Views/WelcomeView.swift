import SwiftUI

struct WelcomeTipPresentation: Equatable {
    let symbol: String
    let title: String
    let detail: String
}

struct WelcomePresentation: Equatable {
    let title: String
    let objective: String
    let tips: [WelcomeTipPresentation]
    let controls: String
    let continueTitle: String
    let continueHint: String

    static let firstRun = WelcomePresentation(
        title: "Welcome to New Arcadia",
        objective: "Stabilize the current operating gap, choose a growth strategy, and earn a Town Charter at 500 residents—then keep growing toward a Regional Capital.",
        tips: [
            WelcomeTipPresentation(
                symbol: "chart.line.uptrend.xyaxis",
                title: "Stabilize",
                detail: "Protect cashflow, utilities, happiness, and jobs before expanding."
            ),
            WelcomeTipPresentation(
                symbol: "arrow.triangle.branch",
                title: "Choose Growth",
                detail: "Commercial Stewardship is cleaner; Industrial Expansion adds jobs faster, with more pollution and utility load."
            ),
            WelcomeTipPresentation(
                symbol: "waveform.path.ecg",
                title: "Diagnose",
                detail: "Use the inspector and data overlays to find the block, service, or budget pressure that needs attention."
            )
        ],
        controls: "Space pauses · 1–3 set speed · ⌘Z undoes · Return starts the city",
        continueTitle: "Start Building",
        continueHint: "Dismisses Welcome and enables city commands at normal speed"
    )

    var accessibilitySummary: String {
        let guidance = tips.map { "\($0.title): \($0.detail)" }.joined(separator: " ")
        return "\(title). \(objective) \(guidance) Keyboard controls: \(controls). Press Return or choose \(continueTitle) to continue."
    }
}

struct WelcomeView: View {
    let continueAction: () -> Void
    @FocusState private var modalHasKeyboardFocus: Bool
    private let presentation = WelcomePresentation.firstRun

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
                    Text(presentation.title)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                    Text(presentation.objective)
                        .font(.title3).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                HStack(alignment: .top, spacing: 28) {
                    ForEach(Array(presentation.tips.enumerated()), id: \.offset) { _, tip in
                        tipView(tip)
                    }
                }
                .frame(maxWidth: 720)
                HStack {
                    Label(presentation.controls, systemImage: "keyboard")
                        .font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    Button(presentation.continueTitle) { dismissWelcome() }
                        .buttonStyle(.borderedProminent).controlSize(.large).tint(GameTheme.accent)
                        .keyboardShortcut(.defaultAction)
                        .accessibilityIdentifier("welcome.start-building")
                        .accessibilityHint(presentation.continueHint)
                }
            }
            .padding(34)
            .frame(width: 820)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.15)))
            .shadow(color: .black.opacity(0.45), radius: 36, y: 18)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(presentation.accessibilitySummary)
        }
        .focusable()
        .focused($modalHasKeyboardFocus)
        .onAppear { modalHasKeyboardFocus = true }
        .onKeyPress(.return) {
            dismissWelcome()
            return .handled
        }
        .accessibilityIdentifier("welcome.blocking-modal")
    }

    private func dismissWelcome() {
        modalHasKeyboardFocus = false
        continueAction()
    }

    private func tipView(_ presentation: WelcomeTipPresentation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: presentation.symbol).font(.title2).foregroundStyle(GameTheme.accent)
            Text(presentation.title).font(.headline)
            Text(presentation.detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
