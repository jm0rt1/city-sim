import SwiftUI

struct FoundationsGuideView: View {
    @ObservedObject var store: CityGameStore
    var compact = false

    var body: some View {
        if let presentation = store.foundationsGuidePresentation {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Label("CITY COACH", systemImage: "signpost.right.and.left.fill")
                        .font(.system(size: GameTheme.hudCriticalTextSize, weight: .heavy, design: .rounded))
                        .foregroundStyle(GameTheme.primaryAction)
                    Spacer()
                    Text("\(presentation.completedCount)/\(presentation.totalCount)")
                        .font(.system(size: GameTheme.hudSupportTextSize, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.secondary)
                    Button { store.dismissFoundationsGuide() } label: {
                        Image(systemName: "xmark")
                            .frame(width: GameTheme.controlMinimum, height: GameTheme.controlMinimum)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Dismiss City Coach")
                }

                if let lesson = presentation.currentLesson {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: lesson.symbol)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(GameTheme.primaryAction)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(lesson.title)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                            Text(lesson.detail)
                                .font(.system(size: GameTheme.hudSupportTextSize, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(compact ? 3 : 4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Button {
                        _ = store.performFoundationsGuideAction()
                    } label: {
                        Label(lesson.actionTitle, systemImage: "arrow.right")
                            .font(.system(size: GameTheme.hudCriticalTextSize, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: GameTheme.controlMinimum, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .background(GameTheme.hudRaisedFill, in: RoundedRectangle(cornerRadius: 9))
                } else {
                    Label("You can now plan, build, diagnose, and recover without guided prompts.", systemImage: "checkmark.seal.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(GameTheme.accent)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Replay lessons") {
                        store.restartFoundationsGuide()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(12)
            .frame(width: compact ? 246 : 276)
            .cityPanelBackground(.thin, in: RoundedRectangle(cornerRadius: 14))
            .background(GameTheme.hudSurfaceFill, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(GameTheme.panelStroke))
            .shadow(color: .black.opacity(0.22), radius: 12, y: 6)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(presentation.accessibilitySummary)
            .accessibilityIdentifier("foundations-guide")
        }
    }
}
