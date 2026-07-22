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

    private var reduceMotion: Bool { systemReduceMotion || gameReduceMotion }

    var body: some View {
        if compact {
            VStack(spacing: 7) {
                HStack(spacing: 7) {
                    cityIdentity
                    Spacer(minLength: 6)
                    timeAndNotices
                }
                .padding(6)
                .hudSurface()

                metricRibbon
                    .padding(.horizontal, 4)
                    .padding(.vertical, 5)
                    .hudSurface()
            }
        } else {
            HStack(spacing: 0) {
                cityIdentity
                    .frame(width: 220)

                hudDivider
                metricRibbon
                hudDivider
                timeAndNotices
            }
            .padding(6)
            .hudSurface()
        }
    }

    private var cityIdentity: some View {
        let objective = store.primaryObjective
        let mandateComplete = store.completedObjectiveCount == store.objectives.count

        return VStack(alignment: .leading, spacing: 4) {
            Button { store.perform(.inspectorOverview) } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.state.cityName)
                            .font(.system(size: compact ? 16 : 17, weight: .bold, design: .rounded))
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            Text(store.state.formattedDay)
                                .foregroundStyle(.secondary)
                            Label(simulationStatus.label, systemImage: simulationStatus.symbol)
                                .fontWeight(.heavy)
                                .foregroundStyle(simulationStatusTint)
                                .accessibilityLabel("Simulation state")
                                .accessibilityValue(simulationStatus.accessibilityValue)
                                .accessibilityIdentifier("hud.simulation.state")
                        }
                        .font(.caption2.monospacedDigit())
                    }
                    Spacer(minLength: 2)
                    Image(systemName: "building.2.crop.circle")
                        .foregroundStyle(GameTheme.accent)
                }
                .frame(minHeight: GameTheme.controlMinimum)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(store.state.cityName) command center")
            .accessibilityValue(store.state.formattedDay)
            .accessibilityIdentifier("hud.city.identity")

            Button {
                withAnimation(GameTheme.animation(reduceMotion: reduceMotion)) {
                    _ = store.perform(.toggleObjectives)
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: mandateComplete ? "checkmark.circle.fill" : "flag.checkered")
                        .foregroundStyle(mandateComplete ? GameTheme.accent : GameTheme.information)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(mandateComplete ? "Mandate complete" : objective.title)
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                            Spacer(minLength: 2)
                            Text("\(store.completedObjectiveCount)/\(store.objectives.count)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(value: objective.progress)
                            .tint(mandateComplete ? GameTheme.accent : GameTheme.information)
                    }
                }
                .frame(minHeight: GameTheme.controlMinimum)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(mandateComplete ? "All objectives achieved" : objective.remaining)
            .accessibilityLabel(store.showObjectives ? "Hide objectives" : "Show objectives")
            .accessibilityValue(mandateComplete ? "All objectives complete" : objective.remaining)
            .accessibilityIdentifier("hud.objective.summary")
        }
        .padding(.horizontal, 7)
    }

    static func simulationState(for speed: SimulationSpeed) -> HUDSimulationStatePresentation {
        if speed == .paused {
            return HUDSimulationStatePresentation(label: "PAUSED", symbol: "pause.fill", accessibilityValue: "Paused")
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
                value: store.state.treasury.currencyText,
                symbol: "dollarsign.circle.fill",
                tint: store.state.treasury >= 0 ? GameTheme.accent : GameTheme.danger,
                detail: "\(store.analytics.projectedBalance.signedCurrencyText) / cycle"
            ) { store.perform(.inspectorFinances) }

            MetricCard(
                identifier: "hud.metric.population",
                title: "Residents",
                value: store.state.population.compactText,
                symbol: "person.3.fill",
                tint: .cyan,
                detail: "\(store.analytics.housingHeadroom.formatted()) homes open",
                progress: store.analytics.housingUtilization
            ) { store.perform(.inspectorPopulation) }

            MetricCard(
                identifier: "hud.metric.happiness",
                title: "Happiness",
                value: store.state.happiness.percentText,
                symbol: "face.smiling.fill",
                tint: store.state.happiness >= 60 ? GameTheme.accent : GameTheme.warning,
                detail: "\(store.state.approval.percentText) mayor approval",
                progress: store.state.happiness / 100
            ) { store.perform(.inspectorHappiness) }

            MetricCard(
                identifier: "hud.metric.employment",
                title: "Jobs filled",
                value: store.state.jobs.compactText,
                symbol: "briefcase.fill",
                tint: .purple,
                detail: "\(store.analytics.jobHeadroom.formatted()) openings",
                progress: store.analytics.jobUtilization
            ) { store.perform(.inspectorEmployment) }

            MetricCard(
                identifier: "hud.metric.utilities",
                title: "Utilities",
                value: (store.analytics.utilityCoverage * 100).percentText,
                symbol: "bolt.horizontal.fill",
                tint: store.analytics.utilityCoverage >= 1 ? GameTheme.accent : GameTheme.danger,
                detail: "P \(store.analytics.powerHeadroom.formatted()) · W \(store.analytics.waterHeadroom.formatted()) spare",
                progress: store.analytics.utilityCoverage
            ) { store.perform(.inspectorUtilities) }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("City status")
    }

    private var timeAndNotices: some View {
        HStack(spacing: 5) {
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
                .help(speed == .paused ? "Pause simulation · Space" : "Set simulation to \(speed.controlLabel) · \(speed.rawValue)")
                .accessibilityLabel(speed == .paused ? "Pause simulation" : "Set simulation speed to \(speed.controlLabel)")
                .accessibilityValue(store.speed == speed ? "Selected" : "Not selected")
                .accessibilityIdentifier("hud.speed.\(speed.rawValue)")
            }

            Divider().frame(height: 28)

            Button { store.perform(.openNotices) } label: {
                if compact {
                    Label("\(store.alertCount)", systemImage: noticeSymbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(noticeColor)
                        .padding(.horizontal, 8)
                        .frame(minHeight: GameTheme.controlMinimum)
                } else {
                    Label("Notices \(store.alertCount)", systemImage: noticeSymbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(noticeColor)
                        .padding(.horizontal, 8)
                        .frame(minHeight: GameTheme.controlMinimum)
                }
            }
            .buttonStyle(.plain)
            .background(GameTheme.inactiveControl, in: RoundedRectangle(cornerRadius: 9))
            .accessibilityLabel("Open city notices")
            .accessibilityValue(noticeAccessibilityValue)
            .accessibilityIdentifier("hud.notices")
        }
        .padding(.horizontal, 4)
    }

    private var hudDivider: some View {
        Rectangle()
            .fill(GameTheme.subtleDivider)
            .frame(width: 1, height: 48)
            .padding(.horizontal, 4)
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

private extension View {
    func hudSurface() -> some View {
        background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GameTheme.panelRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: GameTheme.panelRadius, style: .continuous)
                    .stroke(GameTheme.strongPanelStroke)
            )
            .shadow(color: .black.opacity(0.28), radius: 16, y: 7)
    }
}
