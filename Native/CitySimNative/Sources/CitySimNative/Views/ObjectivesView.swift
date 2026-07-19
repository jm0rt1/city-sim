import SwiftUI

struct ObjectivesView: View {
    @ObservedObject var store: CityGameStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("MAYOR'S MANDATE", systemImage: "flag.checkered")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                Spacer()
                Button { store.showObjectives = false } label: {
                    Image(systemName: "xmark")
                        .frame(width: GameTheme.controlMinimum, height: GameTheme.controlMinimum)
                        .contentShape(Rectangle())
                }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .accessibilityLabel("Hide objectives")
            }
            ForEach(store.objectives) { objective in
                Button { store.openObjective(objective) } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Image(systemName: objective.completed ? "checkmark.circle.fill" : "circle.dashed")
                                .foregroundStyle(objective.completed ? GameTheme.accent : .secondary)
                            Text(objective.title).font(.system(size: 12, weight: .semibold))
                        }
                        Text(objective.detail).font(.caption2).foregroundStyle(.secondary)
                        Text(objective.remaining).font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                        ProgressView(value: objective.progress).tint(objective.completed ? GameTheme.accent : .cyan)
                    }
                    .frame(minHeight: GameTheme.controlMinimum)
                }
                .buttonStyle(.plain)
                .help("Open objective details")
                .accessibilityLabel(objective.title)
                .accessibilityValue(objective.remaining)
            }
        }
        .padding(14)
        .frame(width: 245)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(GameTheme.panelStroke))
    }
}

struct ObjectiveSummaryView: View {
    @ObservedObject var store: CityGameStore
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("reduceGameMotion") private var gameReduceMotion = false

    var body: some View {
        let objective = store.primaryObjective
        Button {
            withAnimation(GameTheme.animation(reduceMotion: systemReduceMotion || gameReduceMotion)) {
                store.showObjectives.toggle()
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
                Text("\(store.completedObjectiveCount)/\(store.objectives.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
        .help(store.showObjectives ? "Hide objectives" : "Show objectives")
        .accessibilityLabel(store.showObjectives ? "Hide objectives" : "Show objectives")
        .accessibilityValue("\(store.completedObjectiveCount) of \(store.objectives.count) complete. \(objective.title), \(objective.remaining)")
    }
}
