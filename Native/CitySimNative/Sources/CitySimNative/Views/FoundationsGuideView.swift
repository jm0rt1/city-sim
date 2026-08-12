import SwiftUI

struct FoundationsGuideView: View {
    @ObservedObject var store: CityGameStore

    var body: some View {
        if let presentation = store.foundationsGuidePresentation {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 8) {
                    Label("FOUNDATIONS GUIDE", systemImage: "signpost.right.and.left.fill")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(GameTheme.accent)
                    Spacer()
                    Text("\(presentation.completedCount)/\(presentation.totalCount)")
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: presentation.progress)
                    .tint(GameTheme.accent)

                if let lesson = presentation.currentLesson {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: lesson.symbol)
                            .font(.title2)
                            .foregroundStyle(.cyan)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(lesson.title)
                                .font(.headline)
                            Text(lesson.detail)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Label(lesson.completionRule, systemImage: "checkmark.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 8) {
                        Button(lesson.actionTitle) {
                            _ = store.performFoundationsGuideAction()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(GameTheme.accent)
                        Spacer()
                        Button("Skip guide") {
                            store.dismissFoundationsGuide()
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }
                } else {
                    Label("You can now plan, build, diagnose, and recover without guided prompts.", systemImage: "checkmark.seal.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(GameTheme.accent)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button("Replay lessons") {
                            store.restartFoundationsGuide()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        Spacer()
                        Button("Close") {
                            store.dismissFoundationsGuide()
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }
                }
            }
            .padding(14)
            .frame(width: 332)
            .cityPanelBackground(.ultraThin, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(GameTheme.panelStroke))
            .shadow(color: .black.opacity(0.22), radius: 12, y: 6)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(presentation.accessibilitySummary)
            .accessibilityIdentifier("foundations-guide")
        }
    }
}
