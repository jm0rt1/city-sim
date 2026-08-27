import SwiftUI

struct FoundationsGuideView: View {
    static let compactCompletionWidth: CGFloat = 160
    static let compactCompletionContextTitle = "CITY COACH"
    static let compactCompletionActionTitle = "Replay"
    static let completionReplayAccessibilityLabel = "Replay City Coach lessons"

    static func completionReplayAccessibilityHint(totalLessonCount: Int) -> String {
        "Restarts all \(totalLessonCount) guided lessons"
    }

    @ObservedObject var store: CityGameStore
    var compact = false

    var body: some View {
        if let presentation = store.foundationsGuidePresentation {
            VStack(
                alignment: .leading,
                spacing: compact && !presentation.isComplete ? 3 : 5
            ) {
                if compact, presentation.isComplete {
                    HStack(spacing: 4) {
                        Button {
                            store.restartFoundationsGuide()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                VStack(alignment: .leading, spacing: -1) {
                                    Text(Self.compactCompletionContextTitle)
                                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                                    Text(Self.compactCompletionActionTitle)
                                        .font(.system(
                                            size: GameTheme.hudCriticalTextSize,
                                            weight: .bold,
                                            design: .rounded
                                        ))
                                }
                                .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, minHeight: GameTheme.controlMinimum)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(GameTheme.accent)
                        .accessibilityLabel(Self.completionReplayAccessibilityLabel)
                        .accessibilityHint(Self.completionReplayAccessibilityHint(
                            totalLessonCount: presentation.totalCount
                        ))

                        Button { store.dismissFoundationsGuide() } label: {
                            Image(systemName: "xmark")
                                .frame(width: GameTheme.controlMinimum, height: GameTheme.controlMinimum)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Dismiss City Coach")
                    }
                } else if compact, let lesson = presentation.currentLesson {
                    HStack(spacing: 6) {
                        Label("CITY COACH", systemImage: "signpost.right.and.left.fill")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(GameTheme.primaryAction)
                        Text("\(presentation.completedCount)/\(presentation.totalCount)")
                            .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Label(lesson.title, systemImage: lesson.symbol)
                        .font(.system(size: 14, weight: .bold, design: .rounded))

                    Text(lesson.detail)
                        .font(.system(size: GameTheme.hudSupportTextSize, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 4) {
                        Button {
                            _ = store.performFoundationsGuideAction()
                        } label: {
                            HStack(spacing: 6) {
                                Text(lesson.actionTitle)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                                Spacer(minLength: 4)
                                Image(systemName: "arrow.right")
                            }
                            .font(.system(size: GameTheme.hudCriticalTextSize, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: GameTheme.controlMinimum)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button { store.dismissFoundationsGuide() } label: {
                            Image(systemName: "xmark")
                                .frame(width: GameTheme.controlMinimum, height: GameTheme.controlMinimum)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Dismiss City Coach")
                    }
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(GameTheme.panelStroke)
                            .frame(height: 1)
                    }
                } else if let lesson = presentation.currentLesson {
                    HStack(alignment: .top, spacing: 6) {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 6) {
                                Label("CITY COACH", systemImage: "signpost.right.and.left.fill")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .foregroundStyle(GameTheme.primaryAction)
                                Text("\(presentation.completedCount)/\(presentation.totalCount)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Label(lesson.title, systemImage: lesson.symbol)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                            Text(lesson.detail)
                                .font(.system(size: GameTheme.hudSupportTextSize, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(compact ? 4 : 3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Button { store.dismissFoundationsGuide() } label: {
                            Image(systemName: "xmark")
                                .frame(width: GameTheme.controlMinimum, height: GameTheme.controlMinimum)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Dismiss City Coach")
                    }

                    Button {
                        _ = store.performFoundationsGuideAction()
                    } label: {
                        HStack(spacing: 6) {
                            Text(lesson.actionTitle)
                            Spacer(minLength: 4)
                            Image(systemName: "arrow.right")
                        }
                            .font(.system(size: GameTheme.hudCriticalTextSize, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: GameTheme.controlMinimum)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(GameTheme.panelStroke)
                            .frame(height: 1)
                    }
                } else {
                    HStack(alignment: .top, spacing: 6) {
                        VStack(alignment: .leading, spacing: 5) {
                            Label("CITY COACH", systemImage: "checkmark.seal.fill")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(GameTheme.accent)
                            Text("You can now plan, build, diagnose, and recover without guided prompts.")
                                .font(.system(size: GameTheme.hudSupportTextSize, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Button { store.dismissFoundationsGuide() } label: {
                            Image(systemName: "xmark")
                                .frame(width: GameTheme.controlMinimum, height: GameTheme.controlMinimum)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Dismiss City Coach")
                    }

                    Button {
                        store.restartFoundationsGuide()
                    } label: {
                        HStack(spacing: 6) {
                            Text("Replay lessons")
                            Spacer(minLength: 4)
                            Image(systemName: "arrow.counterclockwise")
                        }
                        .font(.system(size: GameTheme.hudCriticalTextSize, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: GameTheme.controlMinimum)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Self.completionReplayAccessibilityLabel)
                    .accessibilityHint(Self.completionReplayAccessibilityHint(
                        totalLessonCount: presentation.totalCount
                    ))
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(GameTheme.panelStroke)
                            .frame(height: 1)
                    }
                }
            }
            .padding(.horizontal, compact && !presentation.isComplete ? 9 : 11)
            .padding(.vertical, compact ? (presentation.isComplete ? 3 : 6) : 9)
            .frame(width: compact
                ? (presentation.isComplete ? Self.compactCompletionWidth : GameTheme.compactContextCardWidth)
                : 258)
            .cityHUDSurface()
            .accessibilityElement(children: .contain)
            .accessibilityLabel(presentation.accessibilitySummary)
            .accessibilityIdentifier("foundations-guide")
        }
    }
}
