import SwiftUI

struct BranchNamingView: View {
    let presentation: CityBranchNamingPresentation
    let name: String
    let error: String?
    let canCreate: Bool
    let updateName: (String) -> Void
    let createAction: () -> Void
    let cancelAction: () -> Void
    @FocusState private var nameHasFocus: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.68).ignoresSafeArea()
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(GameTheme.accent.opacity(0.16))
                        .frame(width: 72, height: 72)
                    Image(systemName: presentation.sourceSymbol)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(GameTheme.accent.gradient)
                }
                VStack(spacing: 7) {
                    Text(presentation.title)
                        .font(.system(size: 27, weight: .heavy, design: .rounded))
                    Text(presentation.checkpoint)
                        .font(.headline)
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
                VStack(alignment: .leading, spacing: 6) {
                    Text("Timeline name")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    TextField(
                        "Example: Before the freight expansion",
                        text: Binding(get: { name }, set: { updateName($0) })
                    )
                    .textFieldStyle(.roundedBorder)
                    .focused($nameHasFocus)
                    .onSubmit { if canCreate { createAction() } }
                    .accessibilityIdentifier("branch-naming.name")
                    HStack {
                        if let error {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(GameTheme.warning)
                        } else {
                            Text("1–40 characters · Names must be unique")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(name.count)/40")
                            .monospacedDigit()
                            .foregroundStyle(name.count == 40 ? GameTheme.warning : .secondary)
                    }
                    .font(.caption)
                }
                HStack(spacing: 12) {
                    Button("Cancel", action: cancelAction)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("branch-naming.cancel")
                    Button(presentation.createActionTitle, action: createAction)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(GameTheme.accent)
                        .keyboardShortcut(.defaultAction)
                        .disabled(!canCreate)
                        .accessibilityIdentifier("branch-naming.create")
                }
            }
            .padding(30)
            .frame(width: 650)
            .cityPanelBackground(.regular, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.15)))
            .shadow(color: .black.opacity(0.45), radius: 36, y: 18)
        }
        .onAppear { nameHasFocus = true }
        .accessibilityIdentifier("branch-naming.blocking-modal")
    }
}
