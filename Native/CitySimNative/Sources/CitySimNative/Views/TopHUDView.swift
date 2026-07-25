import SwiftUI

struct HUDSimulationStatePresentation: Equatable {
    let label: String
    let symbol: String
    let accessibilityValue: String
}

struct TopHUDView: View {
    @ObservedObject var store: CityGameStore
    var compact = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("reduceGameMotion") private var gameReduceMotion = false

    static let compactMaximumHeight: CGFloat = 116
    static let regularMaximumHeight: CGFloat = 136

    private var reduceMotion: Bool { systemReduceMotion || gameReduceMotion }

    var body: some View {
        VStack(spacing: 4) {
            statusRow
            StrategyCommandCenterView(store: store, compact: compact)
        }
        .padding(6)
        .frame(maxHeight: compact ? Self.compactMaximumHeight : Self.regularMaximumHeight)
        .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: GameTheme.panelRadius, style: .continuous)
        )
        .background(
            GameTheme.hudSurfaceFill,
            in: RoundedRectangle(cornerRadius: GameTheme.panelRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: GameTheme.panelRadius, style: .continuous)
                .stroke(GameTheme.strongPanelStroke)
        )
        .shadow(color: .black.opacity(0.2), radius: 12, y: 5)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("City command status")
    }

    private var statusRow: some View {
        HStack(spacing: compact ? 4 : 6) {
            cityIdentity
                .frame(width: compact ? 104 : 150)
            objectiveSummary
                .frame(width: compact ? 138 : 184)

            hudDivider
            metricRibbon
            hudDivider
            timeAndNotices
        }
        .frame(minHeight: GameTheme.controlMinimum)
    }

    private var cityIdentity: some View {
        Button { store.perform(.inspectorOverview) } label: {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(store.state.cityName)
                        .font(.system(size: compact ? 14 : 15, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 1)
                    Image(systemName: "building.2.crop.circle")
                        .foregroundStyle(GameTheme.accent)
                        .accessibilityHidden(true)
                }
                HStack(spacing: 5) {
                    Text(store.state.formattedDay)
                        .foregroundStyle(.secondary)
                    Label(simulationStatus.label, systemImage: simulationStatus.symbol)
                        .fontWeight(.heavy)
                        .foregroundStyle(simulationStatusTint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .font(.system(size: GameTheme.hudCriticalTextSize, weight: .semibold, design: .rounded).monospacedDigit())
            }
            .padding(.horizontal, 5)
            .frame(maxWidth: .infinity, minHeight: GameTheme.controlMinimum, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(GameTheme.contextCard.opacity(0.48), in: RoundedRectangle(cornerRadius: 9))
        .accessibilityLabel("Open \(store.state.cityName) command center")
        .accessibilityValue("\(store.state.formattedDay). \(simulationStatus.accessibilityValue)")
        .accessibilityIdentifier("hud.city.identity")
    }

    private var objectiveSummary: some View {
        let objective = store.primaryObjective
        let mandateComplete = store.completedObjectiveCount == store.objectives.count

        return Button {
            withAnimation(GameTheme.animation(reduceMotion: reduceMotion)) {
                _ = store.perform(.toggleObjectives)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: mandateComplete ? "checkmark.circle.fill" : "flag.checkered")
                    .foregroundStyle(mandateComplete ? GameTheme.accent : GameTheme.information)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 3) {
                        Text(mandateComplete ? "Mandate complete" : objective.title)
                            .font(.system(size: GameTheme.hudCriticalTextSize, weight: .bold, design: .rounded))
                            .lineLimit(1)
                        Spacer(minLength: 1)
                        Text("\(store.completedObjectiveCount)/\(store.objectives.count)")
                            .font(.system(size: GameTheme.hudCriticalTextSize, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: objective.progress)
                        .tint(mandateComplete ? GameTheme.accent : GameTheme.information)
                }
            }
            .padding(.horizontal, 5)
            .frame(maxWidth: .infinity, minHeight: GameTheme.controlMinimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(GameTheme.contextCard.opacity(0.48), in: RoundedRectangle(cornerRadius: 9))
        .help(mandateComplete ? "All objectives achieved" : objective.remaining)
        .accessibilityLabel(store.showObjectives ? "Hide objectives" : "Show objectives")
        .accessibilityValue(mandateComplete ? "All objectives complete" : objective.remaining)
        .accessibilityIdentifier("hud.objective.summary")
    }

    static func simulationState(for speed: SimulationSpeed) -> HUDSimulationStatePresentation {
        if speed == .paused {
            return HUDSimulationStatePresentation(
                label: "PAUSED",
                symbol: "pause.fill",
                accessibilityValue: "Paused"
            )
        }
        return HUDSimulationStatePresentation(
            label: "RUNNING \(speed.controlLabel.uppercased())",
            symbol: "play.fill",
            accessibilityValue: "Running at \(speed.controlLabel) speed"
        )
    }

    private var simulationStatus: HUDSimulationStatePresentation {
        Self.simulationState(for: store.speed)
    }

    private var simulationStatusTint: Color {
        store.speed == .paused ? GameTheme.warning : GameTheme.accent
    }

    private var metricRibbon: some View {
        HStack(spacing: 1) {
            MetricCard(
                identifier: "hud.metric.treasury",
                title: "Treasury",
                shortTitle: compact ? "Cash" : nil,
                value: store.state.treasury.currencyText,
                symbol: "dollarsign.circle.fill",
                tint: store.state.treasury >= 0 ? GameTheme.accent : GameTheme.danger,
                detail: compact
                    ? "Net \(store.analytics.projectedBalance.signedCurrencyText)"
                    : "\(store.analytics.projectedBalance.signedCurrencyText) / cycle",
                dense: compact
            ) { store.perform(.inspectorFinances) }

            MetricCard(
                identifier: "hud.metric.population",
                title: "Residents",
                shortTitle: compact ? "People" : nil,
                value: store.state.population.compactText,
                symbol: "person.3.fill",
                tint: .cyan,
                detail: compact
                    ? "Open \(store.analytics.housingHeadroom.compactText)"
                    : "\(store.analytics.housingHeadroom.formatted()) homes open",
                progress: store.analytics.housingUtilization,
                dense: compact
            ) { store.perform(.inspectorPopulation) }

            MetricCard(
                identifier: "hud.metric.happiness",
                title: "Happiness",
                shortTitle: compact ? "Happy" : nil,
                value: store.state.happiness.percentText,
                symbol: "face.smiling.fill",
                tint: store.state.happiness >= 60 ? GameTheme.accent : GameTheme.warning,
                detail: compact ? "Approval \(store.state.approval.percentText)" : "\(store.state.approval.percentText) mayor approval",
                progress: store.state.happiness / 100,
                dense: compact
            ) { store.perform(.inspectorHappiness) }

            MetricCard(
                identifier: "hud.metric.employment",
                title: "Jobs filled",
                shortTitle: "Jobs",
                value: store.state.jobs.compactText,
                symbol: "briefcase.fill",
                tint: .purple,
                detail: compact ? "Open \(store.analytics.jobHeadroom.compactText)" : "\(store.analytics.jobHeadroom.formatted()) openings",
                progress: store.analytics.jobUtilization,
                dense: compact
            ) { store.perform(.inspectorEmployment) }

            MetricCard(
                identifier: "hud.metric.utilities",
                title: "Utilities",
                shortTitle: compact ? "Utility" : nil,
                value: (store.analytics.utilityCoverage * 100).percentText,
                symbol: "bolt.horizontal.fill",
                tint: store.analytics.utilityCoverage >= 1 ? GameTheme.accent : GameTheme.danger,
                detail: "P \(store.analytics.powerHeadroom.formatted()) · W \(store.analytics.waterHeadroom.formatted())",
                progress: store.analytics.utilityCoverage,
                dense: compact
            ) { store.perform(.inspectorUtilities) }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("City status")
    }

    private var timeAndNotices: some View {
        HStack(spacing: 4) {
            ForEach(SimulationSpeed.allCases) { speed in
                Button { store.perform(CityCommandCatalog.id(for: speed)) } label: {
                    Text(speed.controlLabel)
                        .font(.caption.weight(.bold))
                        .frame(minWidth: speed == .paused ? (compact ? 48 : 52) : GameTheme.controlMinimum)
                        .frame(minHeight: GameTheme.controlMinimum)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(store.speed == speed ? Color.black : Color.primary)
                .background(
                    store.speed == speed ? GameTheme.accent : GameTheme.inactiveControl,
                    in: RoundedRectangle(cornerRadius: 9)
                )
                .help(
                    speed == .paused
                        ? "Pause simulation · Space"
                        : "Set simulation to \(speed.controlLabel) · \(speed.rawValue)"
                )
                .accessibilityLabel(
                    speed == .paused ? "Pause simulation" : "Set simulation speed to \(speed.controlLabel)"
                )
                .accessibilityValue(store.speed == speed ? "Selected" : "Not selected")
                .accessibilityIdentifier("hud.speed.\(speed.rawValue)")
            }

            Button { store.perform(.openNotices) } label: {
                Label(compact ? "\(store.alertCount)" : "Notices \(store.alertCount)", systemImage: noticeSymbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(noticeColor)
                    .padding(.horizontal, compact ? 5 : 8)
                    .frame(minWidth: GameTheme.controlMinimum, minHeight: GameTheme.controlMinimum)
            }
            .buttonStyle(.plain)
            .background(GameTheme.inactiveControl, in: RoundedRectangle(cornerRadius: 9))
            .accessibilityLabel("Open city notices")
            .accessibilityValue(noticeAccessibilityValue)
            .accessibilityIdentifier("hud.notices")
        }
    }

    private var hudDivider: some View {
        Rectangle()
            .fill(GameTheme.subtleDivider)
            .frame(width: 1, height: 34)
            .padding(.horizontal, compact ? 1 : 3)
    }

    private var noticeSymbol: String {
        switch store.highestAlertSeverity {
        case .critical: "exclamationmark.octagon.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .information: "info.circle.fill"
        case .good: "sparkles"
        case nil: "bell"
        }
    }

    private var noticeColor: Color {
        switch store.highestAlertSeverity {
        case .critical: GameTheme.danger
        case .warning: GameTheme.warning
        case .information: GameTheme.information
        case .good: GameTheme.accent
        case nil: .secondary
        }
    }

    private var noticeAccessibilityValue: String {
        guard let severity = store.highestAlertSeverity else { return "No active notices" }
        return "\(store.alertCount) notices, highest severity \(severity.rawValue)"
    }
}
