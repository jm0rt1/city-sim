import SwiftUI

struct CityBlockDiagnosisView: View {
    let diagnosis: CitySelectedLocationDiagnosis
    let perform: (CityDirectResponse) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Label("BLOCK DIAGNOSIS", systemImage: "cross.case.fill")
                    .font(.system(size: GameTheme.hudCriticalTextSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(GameTheme.warning)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let primary = diagnosis.responses.first {
                    Button { perform(primary) } label: {
                        Label(primary.title, systemImage: primary.focusesMap ? "scope" : "arrow.up.forward.square")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .frame(minHeight: GameTheme.controlMinimum)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint(hint(for: primary))
                }
                if diagnosis.responses.count > 1 {
                    Menu("More responses") {
                        ForEach(Array(diagnosis.responses.dropFirst())) { response in
                            Button(response.title) { perform(response) }
                                .accessibilityHint(hint(for: response))
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .frame(minHeight: GameTheme.controlMinimum)
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityLabel("More honest responses for selected block")
                }
            }
            Text(diagnosis.cause)
                .font(.system(size: GameTheme.hudCriticalTextSize, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(diagnosis.consequence)
                .font(.system(size: GameTheme.hudSupportTextSize))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GameTheme.hudRaisedFill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(GameTheme.warning.opacity(0.24), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(diagnosis.accessibilitySummary)
        .accessibilityIdentifier("hud.selection.priority-response")
    }

    private func hint(for response: CityDirectResponse) -> String {
        response.explanation + (response.focusesMap ? " Focus returns to the map." : "")
    }
}
