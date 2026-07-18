import SwiftUI

struct ObjectivesView: View {
    @ObservedObject var store: CityGameStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("MAYOR'S MANDATE", systemImage: "flag.checkered")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                Spacer()
                Button { store.showObjectives = false } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
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
                        ProgressView(value: objective.progress).tint(objective.completed ? GameTheme.accent : .cyan)
                    }
                }
                .buttonStyle(.plain)
                .help("Open objective details")
            }
        }
        .padding(14)
        .frame(width: 245)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.1)))
    }
}
