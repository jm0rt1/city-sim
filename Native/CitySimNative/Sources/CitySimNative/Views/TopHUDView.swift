import SwiftUI

struct HUDSimulationStatePresentation: Equatable {
    let label: String
    let symbol: String
    let accessibilityValue: String
}

struct HUDUtilityHeadroomPresentation: Equatable {
    let powerValue: String
    let waterValue: String

    var powerLabel: String { "Power \(powerValue)" }
    var waterLabel: String { "Water \(waterValue)" }
    var accessibilityValue: String {
        "Power headroom \(powerValue), Water headroom \(waterValue)"
    }

    static func make(powerHeadroom: Int, waterHeadroom: Int) -> Self {
        Self(
            powerValue: powerHeadroom.compactText,
            waterValue: waterHeadroom.compactText
        )
    }
}

struct HUDFinancePulsePresentation: Equatable {
    let value: String
    let detail: String
    let isHealthy: Bool

    static func make(
        treasury: Double,
        projectedBalance: Double,
        usesUnlimitedFunds: Bool
    ) -> Self {
        HUDFinancePulsePresentation(
            value: usesUnlimitedFunds ? "Unlimited" : treasury.currencyText,
            detail: "Net \(projectedBalance.signedCurrencyText)",
            isHealthy: usesUnlimitedFunds || projectedBalance >= 0
        )
    }
}

enum HUDMissionSummaryMode: Equatable, Sendable {
    case mayorAction
    case objectiveStatus
}

struct HUDObjectiveStatusPresentation: Equatable {
    let title: String
    let progress: String
    let status: String
    let accessibilityLabel: String
    let accessibilityValue: String

    static func make(
        objective: CityObjective,
        mandateComplete: Bool,
        hasAuthoredScenario: Bool
    ) -> Self {
        let title = mandateComplete
            ? (hasAuthoredScenario ? "Scenario complete" : "Mandate complete")
            : objective.title
        let progress = objective.progress.formatted(
            .percent.precision(.fractionLength(0))
        )
        return Self(
            title: title,
            progress: progress,
            status: mandateComplete ? "Objective complete" : "Objective in progress",
            accessibilityLabel: "Mayor objective: \(title)",
            accessibilityValue: "\(progress) complete. \(objective.remaining)"
        )
    }
}

private struct CompactUtilityMetricCard: View {
    let coverage: String
    let headroom: HUDUtilityHeadroomPresentation
    let progress: Double
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 3) {
                    Text("UTILITY")
                        .font(.system(size: MetricCard.criticalTextSize, weight: .bold, design: .rounded))
                        .tracking(0.15)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(coverage)
                        .font(.system(size: GameTheme.hudMetricValueTextSize, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                Text(headroom.powerLabel)
                    .font(.system(size: MetricCard.supportTextSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(headroom.waterLabel)
                    .font(.system(size: MetricCard.supportTextSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.primary.opacity(0.10))
                        Capsule()
                            .fill(tint)
                            .frame(width: proxy.size.width * min(1, max(0, progress)))
                    }
                }
                .frame(height: 2)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .frame(maxWidth: .infinity, minHeight: GameTheme.controlMinimum, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .frame(minWidth: 60, maxWidth: .infinity, alignment: .leading)
        .background(GameTheme.hudRaisedFill, in: RoundedRectangle(cornerRadius: 9))
        .help("Open utilities details")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Utilities")
        .accessibilityValue("\(coverage), \(headroom.accessibilityValue)")
        .accessibilityIdentifier("hud.metric.utilities")
    }
}

struct TopHUDView: View {
    @ObservedObject var store: CityGameStore
    var compact = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage(CityPlayerPreferenceKey.reduceMotion) private var gameReduceMotion = false

    static let compactMaximumHeight: CGFloat = 64
    static let regularMaximumHeight: CGFloat = 68
    static let compactFinancePulseWidth: CGFloat = 164
    static let regularFinancePulseWidth: CGFloat = 184

    private var reduceMotion: Bool { systemReduceMotion || gameReduceMotion }

    var body: some View {
        statusRow
        .frame(height: compact ? Self.compactMaximumHeight : Self.regularMaximumHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("City command status")
    }

    private var statusRow: some View {
        HStack(spacing: compact ? 6 : 9) {
            cityIdentity
                .frame(width: compact ? 146 : 176)
            missionSummary
                .frame(width: compact ? 286 : 318)
                .layoutPriority(3)
            financePulse
                .frame(width: compact
                    ? Self.compactFinancePulseWidth
                    : Self.regularFinancePulseWidth)
            Spacer(minLength: 4)
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
                    Image(systemName: store.persistenceStatus.symbol)
                        .font(.system(size: compact ? 9 : 11, weight: .bold))
                        .foregroundStyle(persistenceStatusTint)
                        .accessibilityHidden(true)
                }
                HStack(spacing: 5) {
                    Text(store.state.formattedDay)
                        .foregroundStyle(.secondary)
                    if compact {
                        Text(Self.compactSimulationLabel(for: store.speed))
                            .fontWeight(.heavy)
                            .foregroundStyle(simulationStatusTint)
                            .lineLimit(1)
                    } else {
                        Label(simulationStatus.label, systemImage: simulationStatus.symbol)
                            .fontWeight(.heavy)
                            .foregroundStyle(simulationStatusTint)
                            .lineLimit(1)
                    }
                }
                .font(.system(size: GameTheme.hudCriticalTextSize, weight: .semibold, design: .rounded).monospacedDigit())
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: GameTheme.controlMinimum, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cityHUDSurface()
        .help(store.persistenceStatus.help)
        .accessibilityLabel("Open \(store.state.cityName) command center")
        .accessibilityValue(
            "\(store.state.formattedDay). \(simulationStatus.accessibilityValue). \(store.persistenceStatus.label)"
        )
        .accessibilityIdentifier("hud.city.identity")
    }

    @ViewBuilder
    private var missionSummary: some View {
        if Self.missionSummaryMode(
            compact: compact,
            foundationsGuide: store.foundationsGuidePresentation
        ) == .objectiveStatus {
            objectiveStatusSummary
        } else {
            missionActionSummary
        }
    }

    private var objectiveStatusSummary: some View {
        let presentation = HUDObjectiveStatusPresentation.make(
            objective: store.primaryObjective,
            mandateComplete: store.completedObjectiveCount == store.objectives.count,
            hasAuthoredScenario: store.state.authoredScenario != nil
        )

        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "flag.checkered")
                    .accessibilityHidden(true)
                Text(presentation.title)
                    .font(.system(size: GameTheme.hudSupportTextSize, weight: .heavy, design: .rounded))
                    .textCase(.uppercase)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(presentation.progress)
                    .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                    .opacity(0.72)
            }
            HStack(spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(GameTheme.accent)
                    .accessibilityHidden(true)
                Text(presentation.status)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: GameTheme.controlMinimum, alignment: .leading)
        .cityHUDSurface()
        .help("City Coach provides the next action while this lesson is active")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityValue(presentation.accessibilityValue)
        .accessibilityHint("City Coach provides the next action while this lesson is active")
        .accessibilityIdentifier("hud.objective.status")
    }

    private var missionActionSummary: some View {
        let objective = store.primaryObjective
        let mandateComplete = store.completedObjectiveCount == store.objectives.count
        let strategy = CityStrategyHUDPresentation.make(state: store.state)
        let response = strategy.diagnostic ?? strategy.actions.first
        let actionTitle = response.map {
            StrategyCommandCenterView.recoveryRouteTitle(for: $0, compact: true)
        } ?? "Review goal"
        let actionOutcome = response.map(StrategyCommandCenterView.recoveryRouteOutcome)
            ?? objective.remaining

        return Button {
            if let response {
                StrategyCommandCenterView.perform(response, on: store)
            } else {
                withAnimation(GameTheme.animation(reduceMotion: reduceMotion)) {
                    _ = store.perform(.toggleObjectives)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: mandateComplete ? "checkmark.circle.fill" : "flag.checkered")
                        .accessibilityHidden(true)
                    Text(mandateComplete
                        ? (store.state.authoredScenario == nil ? "Mandate complete" : "Scenario complete")
                        : objective.title)
                        .font(.system(size: GameTheme.hudSupportTextSize, weight: .heavy, design: .rounded))
                        .textCase(.uppercase)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(objective.progress, format: .percent.precision(.fractionLength(0)))
                        .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                        .opacity(0.72)
                }
                HStack(spacing: 4) {
                    Text(actionTitle)
                        .font(.system(size: compact ? 15 : 16, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(Color.black.opacity(0.88))
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: GameTheme.controlMinimum, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(GameTheme.primaryAction, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.30), lineWidth: 1)
        )
        .shadow(color: GameTheme.hudShadow, radius: 7, y: 3)
        .disabled(response.map { !store.canPerform($0.command) } ?? false)
        .help(response.flatMap { store.disabledReason(for: $0.command) } ?? response?.explanation ?? objective.remaining)
        .accessibilityLabel(response == nil ? "Review current goal" : "Next action: \(actionTitle)")
        .accessibilityValue("\(objective.remaining). \(actionOutcome)")
        .accessibilityHint(response?.explanation ?? "Opens objective details")
        .accessibilityIdentifier(response == nil ? "hud.objective.summary" : "hud.strategy.primary")
    }

    private func strategyTint(_ tone: CityStrategyHUDTone) -> Color {
        switch tone {
        case .decision: GameTheme.information
        case .active: GameTheme.warning
        case .urgent: GameTheme.danger
        case .recovery, .resolved: GameTheme.accent
        }
    }

    private var financePulse: some View {
        let presentation = HUDFinancePulsePresentation.make(
            treasury: store.state.treasury,
            projectedBalance: store.analytics.projectedBalance,
            usesUnlimitedFunds: store.state.usesUnlimitedFunds
        )
        return MetricCard(
            identifier: "hud.metric.treasury",
            title: "Treasury",
            shortTitle: "Cash",
            value: presentation.value,
            symbol: "dollarsign.circle.fill",
            tint: presentation.isHealthy ? GameTheme.accent : GameTheme.danger,
            detail: presentation.detail,
            dense: true
        ) { store.perform(.inspectorFinances) }
        .accessibilityHint("Opens the city finances and tax decision")
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

    nonisolated static func missionSummaryMode(
        compact: Bool,
        foundationsGuide: CityFoundationsGuidePresentation?
    ) -> HUDMissionSummaryMode {
        compact && foundationsGuide?.currentLesson != nil
            ? .objectiveStatus
            : .mayorAction
    }

    static func compactSimulationLabel(for speed: SimulationSpeed) -> String {
        if speed == .paused { return "Paused" }
        return speed.controlLabel.replacingOccurrences(of: "x", with: "×")
    }

    static func simulationControlAccessibilityLabel(for speed: SimulationSpeed) -> String {
        speed == .paused ? "Resume simulation" : "Pause simulation"
    }

    static func simulationControlHelp(for speed: SimulationSpeed) -> String {
        "\(simulationControlAccessibilityLabel(for: speed)) · Space"
    }

    private var simulationStatus: HUDSimulationStatePresentation {
        Self.simulationState(for: store.speed)
    }

    private var simulationStatusTint: Color {
        store.speed == .paused ? GameTheme.warning : GameTheme.accent
    }

    private var persistenceStatusTint: Color {
        switch store.persistenceStatus.kind {
        case .saved: GameTheme.accent
        case .unsavedChanges: GameTheme.warning
        case .notSaved: .secondary
        }
    }

    private var metricRibbon: some View {
        HStack(spacing: 1) {
            MetricCard(
                identifier: "hud.metric.treasury",
                title: "Treasury",
                shortTitle: "Cash",
                value: treasuryMetricValue,
                symbol: "dollarsign.circle.fill",
                tint: store.state.usesUnlimitedFunds || store.state.treasury >= 0
                    ? GameTheme.accent
                    : GameTheme.danger,
                detail: treasuryMetricDetail,
                dense: true
            ) { store.perform(.inspectorFinances) }

            MetricCard(
                identifier: "hud.metric.population",
                title: "Residents",
                shortTitle: "People",
                value: store.state.population.compactText,
                symbol: "person.3.fill",
                tint: .cyan,
                detail: "Open \(store.analytics.housingHeadroom.compactText)",
                progress: store.analytics.housingUtilization,
                dense: true
            ) { store.perform(.inspectorPopulation) }

            if compact {
                CompactUtilityMetricCard(
                    coverage: (store.analytics.utilityCoverage * 100).percentText,
                    headroom: HUDUtilityHeadroomPresentation.make(
                        powerHeadroom: store.analytics.powerHeadroom,
                        waterHeadroom: store.analytics.waterHeadroom
                    ),
                    progress: store.analytics.utilityCoverage,
                    tint: store.analytics.utilityCoverage >= 1 ? GameTheme.accent : GameTheme.danger
                ) { store.perform(.inspectorUtilities) }
            } else {
                MetricCard(
                    identifier: "hud.metric.utilities",
                    title: "Utilities",
                    shortTitle: "Utility",
                    value: (store.analytics.utilityCoverage * 100).percentText,
                    symbol: "bolt.horizontal.fill",
                    tint: store.analytics.utilityCoverage >= 1 ? GameTheme.accent : GameTheme.danger,
                    detail: "Power \(store.analytics.powerHeadroom.compactText) · Water \(store.analytics.waterHeadroom.compactText)",
                    progress: store.analytics.utilityCoverage,
                    dense: true
                ) { store.perform(.inspectorUtilities) }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Essential city status")
    }

    private var treasuryMetricValue: String {
        store.state.usesUnlimitedFunds ? "Unlimited" : store.state.treasury.currencyText
    }

    private var treasuryMetricDetail: String {
        guard let rules = store.state.sandboxRules else {
            return "Net \(store.analytics.projectedBalance.signedCurrencyText)"
        }
        return "\(rules.economy.title) · \(rules.incidentsEnabled ? "Incidents on" : "No incidents")"
    }

    private var timeAndNotices: some View {
        HStack(spacing: 3) {
            Button { store.perform(.togglePause) } label: {
                Label(
                    store.speed == .paused ? "Resume" : "Pause",
                    systemImage: store.speed == .paused ? "play.fill" : "pause.fill"
                )
                .font(.system(size: GameTheme.hudCriticalTextSize, weight: .heavy, design: .rounded))
                .padding(.horizontal, compact ? 8 : 11)
                .frame(minHeight: GameTheme.controlMinimum)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(store.speed == .paused ? Color.black : Color.primary)
            .background(
                store.speed == .paused ? GameTheme.primaryAction : GameTheme.hudRaisedFill,
                in: RoundedRectangle(cornerRadius: 9)
            )
            .help(Self.simulationControlHelp(for: store.speed))
            .accessibilityLabel(Self.simulationControlAccessibilityLabel(for: store.speed))
            .accessibilityValue(simulationStatus.accessibilityValue)
            .accessibilityIdentifier("hud.speed.paused")

            Menu {
                ForEach(SimulationSpeed.allCases.filter { $0 != .paused }) { speed in
                    Button { store.perform(CityCommandCatalog.id(for: speed)) } label: {
                        Label(
                            speed.controlLabel,
                            systemImage: store.speed == speed ? "checkmark.circle.fill" : "gauge.with.dots.needle.50percent"
                        )
                    }
                    .accessibilityLabel("Set simulation speed to \(speed.controlLabel)")
                    .accessibilityValue(store.speed == speed ? "Selected" : "Not selected")
                    .accessibilityIdentifier("hud.speed.\(speed.rawValue)")
                }
            } label: {
                Label(
                    store.speed == .paused ? "Speed" : Self.compactSimulationLabel(for: store.speed),
                    systemImage: "gauge.with.dots.needle.50percent"
                )
                .font(.system(size: GameTheme.hudCriticalTextSize, weight: .bold, design: .rounded))
                .padding(.horizontal, compact ? 5 : 8)
                .frame(minWidth: GameTheme.controlMinimum, minHeight: GameTheme.controlMinimum)
            }
            .menuStyle(.borderlessButton)
            .accessibilityLabel("Simulation speed")
            .accessibilityValue(simulationStatus.accessibilityValue)

            Button { store.perform(.openNotices) } label: {
                Image(systemName: noticeSymbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(noticeColor)
                    .frame(minWidth: GameTheme.controlMinimum, minHeight: GameTheme.controlMinimum)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open city notices")
            .accessibilityValue(noticeAccessibilityValue)
            .accessibilityIdentifier("hud.notices")
        }
        .padding(3)
        .cityHUDSurface()
    }

    private var hudDivider: some View {
        Rectangle()
            .fill(GameTheme.subtleDivider)
            .frame(width: 1, height: 38)
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

struct FocusCityNoticeUrgencyPresentation: Equatable {
    let count: Int
    let severity: MessageSeverity?

    var compactLabel: String {
        guard count > 0, severity != nil else { return "0" }
        return "\(severityLabel) \(count)"
    }

    var regularLabel: String {
        guard count > 0, severity != nil else { return "No notices" }
        return "\(count) \(severityLabel)"
    }

    var accessibilityValue: String {
        guard count > 0, let severity else { return "No active notices" }
        let noticeCount = count == 1 ? "1 notice" : "\(count) notices"
        return "\(noticeCount), highest severity \(severity.rawValue)"
    }

    private var severityLabel: String {
        switch severity {
        case .critical: "CRITICAL"
        case .warning: "WARNING"
        case .information: "INFO"
        case .good: "GOOD"
        case nil: "NONE"
        }
    }
}

struct FocusCityHUDView: View {
    @ObservedObject var store: CityGameStore
    var compact = false
    let pointerTransitionGate: CityMapPointerTransitionGate

    static let compactMaximumHeight: CGFloat = 98
    static let regularMaximumHeight: CGFloat = 68

    private var strategy: CityStrategyHUDPresentation {
        CityStrategyHUDPresentation.make(state: store.state)
    }

    private var simulationStatus: HUDSimulationStatePresentation {
        TopHUDView.simulationState(for: store.speed)
    }

    private var noticeUrgency: FocusCityNoticeUrgencyPresentation {
        FocusCityNoticeUrgencyPresentation(
            count: store.alertCount,
            severity: store.highestAlertSeverity
        )
    }

    var body: some View {
        Group {
            if compact {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        identity
                        treasury
                        priority
                        noticesButton
                        Spacer(minLength: 4)
                        exitButton
                    }
                    HStack(spacing: 6) {
                        selectedContext
                        Spacer(minLength: 4)
                        speedControls
                    }
                }
            } else {
                HStack(spacing: 8) {
                    identity
                    railDivider
                    treasury
                    railDivider
                    priority
                    noticesButton
                    railDivider
                    selectedContext
                    Spacer(minLength: 4)
                    speedControls
                    exitButton
                }
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .frame(maxHeight: compact ? Self.compactMaximumHeight : Self.regularMaximumHeight)
        .cityPanelBackground(
            .thin,
            in: RoundedRectangle(cornerRadius: GameTheme.panelRadius, style: .continuous)
        )
        .background(
            GameTheme.hudSurfaceFill,
            in: RoundedRectangle(cornerRadius: GameTheme.panelRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: GameTheme.panelRadius, style: .continuous)
                .stroke(GameTheme.accent.opacity(0.55), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.2), radius: 12, y: 5)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Focus City status rail")
        .accessibilityValue("Focus City active")
        .accessibilityIdentifier("hud.focus-city.rail")
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(store.state.cityName)
                .font(.system(size: compact ? 13 : 14, weight: .bold, design: .rounded))
                .lineLimit(1)
            Text("\(store.state.formattedDay) · \(simulationStatus.label)")
                .font(.system(size: GameTheme.hudCriticalTextSize, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(store.speed == .paused ? GameTheme.warning : GameTheme.accent)
                .lineLimit(1)
        }
        .frame(minWidth: compact ? 112 : 142, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(store.state.cityName)
        .accessibilityValue("\(store.state.formattedDay). \(simulationStatus.accessibilityValue)")
        .accessibilityIdentifier("hud.focus-city.identity")
    }

    private var treasury: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(treasuryMetricValue)
                .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
            Text(treasuryMetricDetail)
                .font(.system(size: GameTheme.hudSupportTextSize, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(treasuryTint)
        }
        .frame(minWidth: compact ? 94 : 112, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Treasury")
        .accessibilityValue(
            treasuryAccessibilityValue
        )
        .accessibilityIdentifier("hud.focus-city.treasury")
    }

    private var treasuryMetricValue: String {
        store.state.usesUnlimitedFunds ? "Unlimited" : store.state.treasury.currencyText
    }

    private var treasuryMetricDetail: String {
        guard let rules = store.state.sandboxRules else {
            return "Net \(store.analytics.projectedBalance.signedCurrencyText)"
        }
        return "\(rules.economy.title) · \(rules.incidentsEnabled ? "Incidents on" : "No incidents")"
    }

    private var treasuryAccessibilityValue: String {
        guard let rules = store.state.sandboxRules else {
            return "\(store.state.treasury.currencyText), \(store.analytics.projectedBalance.signedCurrencyText) per cycle"
        }
        let funding = rules.unlimitedFunds
            ? "Unlimited funds; treasury fixed at \(store.state.treasury.currencyText)"
            : "Treasury \(store.state.treasury.currencyText), net \(store.analytics.projectedBalance.signedCurrencyText) per cycle"
        return "\(funding). \(rules.summary)"
    }

    private var priority: some View {
        HStack(spacing: 5) {
            Image(systemName: prioritySymbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(priorityTint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(strategy.status)
                    .font(.system(size: GameTheme.hudCriticalTextSize, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(priorityTint)
                    .lineLimit(1)
                Text(strategy.title)
                    .font(.system(size: GameTheme.hudSupportTextSize, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: compact ? 224 : 260, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Strategy priority: \(strategy.title)")
        .accessibilityValue(strategy.accessibilityValue)
        .accessibilityIdentifier("hud.focus-city.urgency")
    }

    private var selectedContext: some View {
        HStack(spacing: 5) {
            Image(systemName: selectedContextSymbol)
                .foregroundStyle(selectedContextTint)
                .accessibilityHidden(true)
            Text(selectedContextTitle)
                .font(.system(size: GameTheme.hudCriticalTextSize, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .frame(maxWidth: compact ? .infinity : 286, minHeight: GameTheme.controlMinimum, alignment: .leading)
        .background(GameTheme.contextCard.opacity(0.55), in: RoundedRectangle(cornerRadius: 9))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(selectedContextAccessibilityLabel)
        .accessibilityValue(selectedContextAccessibilityValue)
        .accessibilityHint("Return uses the announced primary action on the focused city map")
        .accessibilityIdentifier("hud.focus-city.selected-context")
    }

    private var noticesButton: some View {
        Button { store.perform(.openNotices) } label: {
            Label(
                compact ? noticeUrgency.compactLabel : noticeUrgency.regularLabel,
                systemImage: noticeSymbol
            )
            .font(.system(size: GameTheme.hudCriticalTextSize, weight: .bold, design: .rounded))
            .foregroundStyle(noticeTint)
            .lineLimit(1)
            .padding(.horizontal, compact ? 5 : 8)
            .frame(minWidth: GameTheme.controlMinimum, minHeight: GameTheme.controlMinimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(noticeTint.opacity(0.14), in: RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(noticeTint.opacity(0.5), lineWidth: noticeUrgency.severity == .critical ? 1.5 : 1)
        )
        .help("Open the city notice journal")
        .accessibilityLabel("Open city notices")
        .accessibilityValue(noticeUrgency.accessibilityValue)
        .accessibilityHint("Exit Focus City and open the existing notice journal")
        .accessibilityIdentifier("hud.focus-city.notices")
    }

    private var speedControls: some View {
        HStack(spacing: 4) {
            ForEach(SimulationSpeed.allCases) { speed in
                Button { store.perform(CityCommandCatalog.id(for: speed)) } label: {
                    Text(speed.controlLabel)
                        .font(.caption.weight(.bold))
                        .frame(minWidth: speed == .paused ? 48 : GameTheme.controlMinimum)
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
                        ? TopHUDView.simulationControlHelp(for: store.speed)
                        : "Set simulation to \(speed.controlLabel) · \(speed.rawValue)"
                )
                .accessibilityLabel(
                    speed == .paused
                        ? TopHUDView.simulationControlAccessibilityLabel(for: store.speed)
                        : "Set simulation speed to \(speed.controlLabel)"
                )
                .accessibilityValue(store.speed == speed ? "Selected" : "Not selected")
                .accessibilityIdentifier("hud.focus-city.speed.\(speed.rawValue)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Focus City simulation speed")
    }

    private var exitButton: some View {
        let descriptor = CityCommandCatalog.descriptor(for: .toggleCityFocus)
        return Button { store.perform(.toggleCityFocus) } label: {
            Label(compact ? "Exit" : "Exit Focus City", systemImage: "viewfinder.circle")
                .font(.system(size: GameTheme.hudCriticalTextSize, weight: .bold))
                .padding(.horizontal, compact ? 6 : 9)
                .frame(minWidth: GameTheme.controlMinimum, minHeight: GameTheme.controlMinimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.black)
        .background(GameTheme.accent, in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            CityFocusPointerTransitionMonitor(pointerTransitionGate: pointerTransitionGate)
                .accessibilityHidden(true)
        }
        .help("Return to the full command surface · \(descriptor.shortcut?.display ?? "")")
        .accessibilityLabel("Exit Focus City")
        .accessibilityValue(descriptor.shortcut?.display ?? "No shortcut")
        .accessibilityHint("Restore the full command surface without changing the active city target")
        .accessibilityIdentifier("hud.focus-city.exit")
    }

    private var railDivider: some View {
        Rectangle()
            .fill(GameTheme.subtleDivider)
            .frame(width: 1, height: 34)
    }

    private var treasuryTint: Color {
        store.state.usesUnlimitedFunds || store.analytics.projectedBalance >= 0
            ? GameTheme.accent
            : GameTheme.danger
    }

    private var priorityTint: Color {
        switch strategy.tone {
        case .decision: GameTheme.information
        case .active: GameTheme.warning
        case .urgent: GameTheme.danger
        case .recovery, .resolved: GameTheme.accent
        }
    }

    private var prioritySymbol: String {
        switch strategy.tone {
        case .decision: "signpost.right.and.left.fill"
        case .active: "scope"
        case .urgent: "exclamationmark.triangle.fill"
        case .recovery: "arrow.trianglehead.2.clockwise.rotate.90"
        case .resolved: "checkmark.seal.fill"
        }
    }

    private var noticeSymbol: String {
        switch noticeUrgency.severity {
        case .critical: "exclamationmark.octagon.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .information: "info.circle.fill"
        case .good: "sparkles"
        case nil: "bell"
        }
    }

    private var noticeTint: Color {
        switch noticeUrgency.severity {
        case .critical: GameTheme.danger
        case .warning: GameTheme.warning
        case .information: GameTheme.information
        case .good: GameTheme.accent
        case nil: .secondary
        }
    }

    private var selectedContextTitle: String {
        switch store.interactionMode {
        case .inspect:
            guard let tile = store.selectedTile else { return "Inspect · No block selected" }
            return "Inspect \(tile.kind.title) · Block \(tile.coordinate.x + 1), \(tile.coordinate.y + 1)"
        case .build(let kind):
            guard let target = store.activeMapActionTargetPresentation else {
                return "Build \(kind.title) · Choose a block"
            }
            return "\(kind.title) · Block \(target.coordinate.x + 1), \(target.coordinate.y + 1) · "
                + (target.primaryAction.isAvailable ? "Ready" : "Blocked")
        case .bulldoze:
            guard let target = store.activeMapActionTargetPresentation else {
                return "Bulldoze · Choose a structure"
            }
            return "Bulldoze · Block \(target.coordinate.x + 1), \(target.coordinate.y + 1) · "
                + (target.primaryAction.isAvailable ? "Ready" : "Blocked")
        }
    }

    private var selectedContextSymbol: String {
        if let target = store.activeMapActionTargetPresentation {
            return target.primaryAction.isAvailable ? "mappin.circle.fill" : "exclamationmark.triangle.fill"
        }
        return store.interactionMode.symbol
    }

    private var selectedContextTint: Color {
        if let target = store.activeMapActionTargetPresentation {
            return target.primaryAction.isAvailable ? GameTheme.accent : GameTheme.warning
        }
        return GameTheme.information
    }

    private var selectedContextAccessibilityLabel: String {
        if let target = store.activeMapActionTargetPresentation {
            return target.primaryAction.name
        }
        return switch store.interactionMode {
        case .inspect: "Inspect mode"
        case .build(let kind): "Build \(kind.title)"
        case .bulldoze: "Bulldoze mode"
        }
    }

    private var selectedContextAccessibilityValue: String {
        if let target = store.activeMapActionTargetPresentation {
            return target.primaryAction.disclosure
        }
        switch store.interactionMode {
        case .inspect:
            return store.selectedTile.map {
                "Selected \($0.kind.title) at block \($0.coordinate.x + 1), \($0.coordinate.y + 1)"
            } ?? "No block selected"
        case .build(let kind):
            return "Selected \(kind.title). Cost \(kind.buildCost.currencyText). "
                + "Choose a block for the authoritative operating forecast."
        case .bulldoze:
            return "Choose a structure. Protected structures and open land remain unavailable."
        }
    }
}
