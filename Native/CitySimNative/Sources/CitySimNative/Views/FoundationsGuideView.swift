import SwiftUI

struct FoundationsGuideView: View {
    static let compactCompletionWidth: CGFloat = 160

    @ObservedObject var store: CityGameStore
    var compact = false

    var body: some View {
        if let presentation = store.foundationsGuidePresentation {
            VStack(alignment: .leading, spacing: 5) {
                if compact, presentation.isComplete {
                    HStack(spacing: 4) {
                        Button {
                            store.restartFoundationsGuide()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                Text("Replay")
                                Image(systemName: "arrow.counterclockwise")
                            }
                            .font(.system(
                                size: GameTheme.hudCriticalTextSize,
                                weight: .bold,
                                design: .rounded
                            ))
                            .frame(maxWidth: .infinity, minHeight: GameTheme.controlMinimum)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(GameTheme.accent)
                        .accessibilityLabel("Replay City Coach lessons")
                        .accessibilityHint("Restarts all \(presentation.totalCount) guided lessons")

                        Button { store.dismissFoundationsGuide() } label: {
                            Image(systemName: "xmark")
                                .frame(width: GameTheme.controlMinimum, height: GameTheme.controlMinimum)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Dismiss City Coach")
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
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(GameTheme.panelStroke)
                            .frame(height: 1)
                    }
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, compact && presentation.isComplete ? 3 : 9)
            .frame(width: compact
                ? (presentation.isComplete ? Self.compactCompletionWidth : 238)
                : 258)
            .cityHUDSurface()
            .accessibilityElement(children: .contain)
            .accessibilityLabel(presentation.accessibilitySummary)
            .accessibilityIdentifier("foundations-guide")
        }
    }
}
