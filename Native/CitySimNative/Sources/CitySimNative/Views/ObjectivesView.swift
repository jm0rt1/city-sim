import SwiftUI

struct ObjectivesView: View {
    @ObservedObject var store: CityGameStore
    @State private var expandedObjectiveID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("MAYOR'S MANDATE", systemImage: "flag.checkered")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                Spacer()
                Button { store.perform(.toggleObjectives) } label: {
                    Image(systemName: "xmark")
                        .frame(width: GameTheme.controlMinimum, height: GameTheme.controlMinimum)
                        .contentShape(Rectangle())
                }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .accessibilityLabel("Hide objectives")
            }
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(store.objectivePresentations) { presentation in
                        objectiveCard(presentation)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: 445)
        }
        .padding(14)
        .frame(width: 332)
        .cityPanelBackground(.ultraThin, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(GameTheme.panelStroke))
    }

    private func objectiveCard(_ presentation: CityObjectivePresentation) -> some View {
        let objective = presentation.objective
        let expanded = expandedObjectiveID == presentation.id
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: objective.completed ? "checkmark.circle.fill" : "circle.dashed")
                    .foregroundStyle(objective.completed ? GameTheme.accent : .secondary)
                Text(objective.title)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Label(presentation.trend.title, systemImage: presentation.trend.symbol)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(trendColor(presentation.trend))
            }

            Text(objective.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 8) {
                metric("CURRENT", presentation.currentValue)
                Image(systemName: "arrow.right")
                    .font(.caption2.bold())
                    .foregroundStyle(.tertiary)
                    .padding(.top, 14)
                metric("TARGET", presentation.targetValue)
            }

            ProgressView(value: objective.progress)
                .tint(objective.completed ? GameTheme.accent : .cyan)

            Label(presentation.persistence, systemImage: "repeat")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Label(presentation.deadline, systemImage: "clock")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Label(presentation.reward, systemImage: "star.fill")
                .font(.caption2.weight(.medium))
                .foregroundStyle(GameTheme.accent)

            if expanded {
                Divider()
                rule("PASS", presentation.passRule, symbol: "checkmark.seal")
                rule("FAIL", presentation.failRule, symbol: "exclamationmark.triangle")
            }

            HStack(spacing: 8) {
                Button(expanded ? "Hide rules" : "Show rules") {
                    expandedObjectiveID = expanded ? nil : presentation.id
                }
                .buttonStyle(.borderless)
                Spacer()
                Button {
                    store.openObjective(objective)
                } label: {
                    Label(presentation.diagnosticLabel, systemImage: "waveform.path.ecg")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(10)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.primary.opacity(0.08)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(presentation.accessibilitySummary)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .rounded))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption2.weight(.semibold))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rule(_ label: String, _ value: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: symbol).frame(width: 12)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 8, weight: .heavy, design: .rounded))
                Text(value).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func trendColor(_ trend: CityObjectiveTrend) -> Color {
        switch trend {
        case .improving, .complete: GameTheme.accent
        case .slipping: .orange
        case .baseline, .steady: .secondary
        }
    }
}

struct ObjectiveSummaryView: View {
    @ObservedObject var store: CityGameStore
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("reduceGameMotion") private var gameReduceMotion = false

    var body: some View {
        let presentation = store.primaryObjectivePresentation
        let objective = presentation.objective
        Button {
            withAnimation(GameTheme.animation(reduceMotion: systemReduceMotion || gameReduceMotion)) {
                _ = store.perform(.toggleObjectives)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: objective.completed ? "checkmark.circle.fill" : "flag.checkered")
                    .foregroundStyle(objective.completed ? GameTheme.accent : .cyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text(objective.completed ? "Mandate complete" : objective.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(objective.remaining)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    ProgressView(value: objective.progress)
                        .frame(width: 108)
                        .tint(objective.completed ? GameTheme.accent : .cyan)
                }
                Label(presentation.trend.title, systemImage: presentation.trend.symbol)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("\(store.completedObjectiveCount)/\(store.objectives.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .cityPanelBackground(.ultraThin, in: RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
        .help(store.showObjectives ? "Hide objectives" : "Show objectives")
        .accessibilityLabel(store.showObjectives ? "Hide objectives" : "Show objectives")
        .accessibilityValue("\(store.completedObjectiveCount) of \(store.objectives.count) complete. \(presentation.accessibilitySummary)")
    }
}
