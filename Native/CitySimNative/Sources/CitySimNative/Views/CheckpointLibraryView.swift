import SwiftUI

struct CheckpointLibraryView: View {
    let presentation: CityCheckpointLibraryPresentation
    let supportFeedback: CityCheckpointSupportFeedback?
    let selectAction: (String) -> Void
    let branchAction: (String) -> Void
    let exportSupportReportAction: (String) -> Void
    let cancelAction: () -> Void
    @FocusState private var focusedCheckpointID: String?

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 1_100 || proxy.size.height < 700
            let cardHeight: CGFloat = compact ? 86 : 96
            let desiredHeight = cardHeight * CGFloat(presentation.cards.count)
                + (compact ? 168 : 188)
            let panelHeight = min(
                proxy.size.height - 40,
                min(compact ? 540 : 650, max(compact ? 420 : 470, desiredHeight))
            )
            ZStack {
                Color.black.opacity(0.68).ignoresSafeArea()
                VStack(alignment: .leading, spacing: compact ? 14 : 18) {
                    header(compact: compact)
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(presentation.cards) { card in
                                checkpointCard(card, compact: compact)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollIndicators(.visible)

                    if let supportFeedback {
                        Label(
                            supportFeedback.message,
                            systemImage: supportFeedback.isError
                                ? "exclamationmark.triangle.fill"
                                : "doc.badge.checkmark"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(
                            supportFeedback.isError ? GameTheme.warning : GameTheme.accent
                        )
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("checkpoint-library.support-feedback")
                    }

                    HStack {
                        Label(
                            "\(presentation.verifiedCount) verified",
                            systemImage: "checkmark.shield.fill"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(GameTheme.accent)
                        if presentation.invalidCount > 0 {
                            Label(
                                "\(presentation.invalidCount) unavailable",
                                systemImage: "exclamationmark.triangle.fill"
                            )
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(GameTheme.warning)
                        }
                        Spacer()
                        Button("Return to Current City", action: cancelAction)
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .keyboardShortcut(.cancelAction)
                            .accessibilityIdentifier("checkpoint-library.cancel")
                    }
                }
                .padding(compact ? 20 : 26)
                .frame(
                    width: min(proxy.size.width - 40, compact ? 760 : 840),
                    height: panelHeight
                )
                .cityPanelBackground(.regular, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.15)))
                .shadow(color: .black.opacity(0.45), radius: 36, y: 18)
            }
        }
        .onAppear {
            focusedCheckpointID = presentation.cards.first(where: \.isLoadable)?.id
        }
        .accessibilityIdentifier("checkpoint-library.blocking-modal")
    }

    private func header(compact: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "externaldrive.fill.badge.timemachine")
                .font(.system(size: compact ? 30 : 36, weight: .semibold))
                .foregroundStyle(GameTheme.accent.gradient)
                .frame(width: compact ? 46 : 54, height: compact ? 46 : 54)
                .background(GameTheme.accent.opacity(0.14), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(presentation.title)
                    .font(.system(size: compact ? 24 : 28, weight: .heavy, design: .rounded))
                Text(presentation.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func checkpointCard(
        _ card: CityCheckpointCardPresentation,
        compact: Bool
    ) -> some View {
        HStack(spacing: compact ? 12 : 16) {
                Image(systemName: card.sourceSymbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(card.isLoadable ? GameTheme.accent : GameTheme.warning)
                    .frame(width: 36, height: 36)
                    .background(
                        (card.isLoadable ? GameTheme.accent : GameTheme.warning).opacity(0.12),
                        in: Circle()
                    )
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(card.title)
                            .font(.headline)
                        Text(card.sourceLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        if card.id == presentation.cards.first(where: \.isLoadable)?.id {
                            Text(compact ? "Latest" : "Most recent")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(GameTheme.accent)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(GameTheme.accent.opacity(0.12), in: Capsule())
                        }
                    }
                    Text(card.checkpoint)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                    Text(card.detail)
                        .font(.caption)
                        .foregroundStyle(card.isLoadable ? Color.secondary : GameTheme.warning)
                        .lineLimit(compact ? 1 : 2)
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 5) {
                    Label(card.integrityLabel, systemImage: card.integritySymbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(card.isLoadable ? GameTheme.accent : GameTheme.warning)
                    Text(
                        card.modifiedAt,
                        format: .dateTime.month(.abbreviated).day().hour().minute()
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    if card.isLoadable {
                        HStack(spacing: 8) {
                            Button("Branch") { branchAction(card.id) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .accessibilityHint("Preserves this checkpoint under a new timeline name")
                            Button("Load") { selectAction(card.id) }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .tint(GameTheme.accent)
                                .focused($focusedCheckpointID, equals: card.id)
                                .accessibilityHint("Loads this checkpoint after protecting the current city")
                        }
                    } else if card.canExportSupportReport {
                        Button("Export Report") { exportSupportReportAction(card.id) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .accessibilityHint(
                                "Creates a sanitized diagnostic report and leaves the recovery file unchanged"
                            )
                    }
                }
            }
            .padding(compact ? 12 : 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                card.isLoadable ? Color.white.opacity(0.055) : GameTheme.warning.opacity(0.07),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        card.isLoadable ? GameTheme.panelStroke : GameTheme.warning.opacity(0.4),
                        lineWidth: 1
                    )
            )
            .contentShape(Rectangle())
        .opacity(card.isLoadable ? 1 : 0.82)
        .accessibilityLabel(card.accessibilitySummary)
        .accessibilityIdentifier("checkpoint-library.card.\(card.id)")
    }
}
