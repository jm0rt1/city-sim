import SwiftUI

enum CityStrategyHUDTone: Equatable {
    case decision
    case active
    case urgent
    case recovery
    case resolved
}

struct CityStrategyHUDPresentation: Equatable {
    let eyebrow: String
    let title: String
    let status: String
    let summary: String
    let tone: CityStrategyHUDTone
    let diagnostic: CityDirectResponse?
    let actions: [CityDirectResponse]

    var accessibilityValue: String {
        [status, summary].filter { !$0.isEmpty }.joined(separator: ". ")
    }

    static func make(analytics: CityAnalytics) -> CityStrategyHUDPresentation {
        guard !analytics.awaitingStrategyChoice,
              let strategy = analytics.committedStrategy else {
            return CityStrategyHUDPresentation(
                eyebrow: "CITY PRIORITY",
                title: "Choose a growth engine",
                status: "DECISION READY",
                summary: "Commercial is steadier; Industrial pays faster with heavier utility and pollution pressure.",
                tone: .decision,
                diagnostic: nil,
                actions: [
                    CityDirectResponse(
                        title: "Choose Commercial",
                        command: .buildCommercial,
                        explanation: "Select Commercial and return focus to the map to place the first eligible project.",
                        focusesMap: true
                    ),
                    CityDirectResponse(
                        title: "Choose Industrial",
                        command: .buildIndustrial,
                        explanation: "Select Industrial and return focus to the map to place the first eligible project.",
                        focusesMap: true
                    )
                ]
            )
        }

        if let secondActPhase = analytics.secondActPhase {
            return regional(
                strategy: strategy,
                phase: secondActPhase,
                days: analytics.secondActDaysUntilConsequence,
                statusText: analytics.regionalCapitalStatusText
            )
        }

        guard let phase = analytics.strategyPhase else {
            return CityStrategyHUDPresentation(
                eyebrow: "CITY PRIORITY",
                title: "Review the current objective",
                status: "CITY ACTIVE",
                summary: analytics.townCharterStatusText,
                tone: .active,
                diagnostic: nil,
                actions: []
            )
        }

        return switch strategy {
        case .commercialStewardship:
            commercial(
                phase: phase,
                days: analytics.strategyDaysUntilConsequence,
                resolution: analytics.strategyRecoveryResolution
            )
        case .industrialExpansion:
            industrial(
                phase: phase,
                days: analytics.strategyDaysUntilConsequence,
                resolution: analytics.strategyRecoveryResolution
            )
        }
    }

    private static func regional(
        strategy: CityStrategy,
        phase: CitySecondActPhase,
        days: Int?,
        statusText: String
    ) -> CityStrategyHUDPresentation {
        let commercial = strategy == .commercialStewardship
        let diagnostic = CityDirectResponse(
            title: commercial ? "Tax policy & cashflow" : "Utility capacity",
            command: commercial ? .inspectorFinances : .inspectorUtilities,
            explanation: commercial
                ? "Review current tax policy, revenue, and upkeep through the existing Command Center."
                : "Review current power, water, coverage, and reserve through the existing Command Center.",
            focusesMap: false
        )
        let actions: [CityDirectResponse] = commercial
            ? [
                CityDirectResponse(
                    title: "Review tax policy",
                    command: .inspectorFinances,
                    explanation: "Tax relief may support demand but reduces revenue.",
                    focusesMap: false
                ),
                CityDirectResponse(
                    title: "Build a park",
                    command: .buildPark,
                    explanation: "Select Park and return focus to the map; placement does not guarantee recovery.",
                    focusesMap: true
                ),
            ]
            : [
                CityDirectResponse(
                    title: "Add power",
                    command: .buildPowerPlant,
                    explanation: "Select Power Plant and return focus to the map; placement does not guarantee recovery.",
                    focusesMap: true
                ),
                CityDirectResponse(
                    title: "Add water",
                    command: .buildWaterTower,
                    explanation: "Select Water Tower and return focus to the map; placement does not guarantee recovery.",
                    focusesMap: true
                ),
                CityDirectResponse(
                    title: "Add green buffer",
                    command: .buildPark,
                    explanation: "Select Park and return focus to the map; placement does not guarantee recovery.",
                    focusesMap: true
                ),
            ]
        let eyebrow = commercial ? "REGIONAL MAIN STREET" : "REGIONAL FREIGHT"

        return switch phase {
        case .mandate:
            .init(
                eyebrow: eyebrow,
                title: "Regional Capital mandate",
                status: timedStatus("MANDATE", days: days),
                summary: statusText,
                tone: .active,
                diagnostic: diagnostic,
                actions: actions
            )
        case .warnedPressure:
            .init(
                eyebrow: eyebrow,
                title: commercial ? "Protect regional retail" : "Protect the regional grid",
                status: timedStatus("PRESSURE", days: days),
                summary: statusText,
                tone: .urgent,
                diagnostic: diagnostic,
                actions: actions
            )
        case .recovery:
            .init(
                eyebrow: eyebrow,
                title: commercial ? "Restore regional retail" : "Recover regional freight",
                status: "RECOVERY",
                summary: statusText,
                tone: .recovery,
                diagnostic: diagnostic,
                actions: actions
            )
        case .qualification:
            .init(
                eyebrow: eyebrow,
                title: "Sustain Regional Capital standards",
                status: "QUALIFYING",
                summary: statusText,
                tone: .active,
                diagnostic: diagnostic,
                actions: []
            )
        case .completed:
            .init(
                eyebrow: commercial ? "REGIONAL MAIN STREET CAPITAL" : "REGIONAL FREIGHT CAPITAL",
                title: "Regional Capital secured",
                status: "RECOGNIZED",
                summary: statusText,
                tone: .resolved,
                diagnostic: diagnostic,
                actions: []
            )
        }
    }

    private static func commercial(
        phase: CityStrategyPhase,
        days: Int?,
        resolution: CityStrategyRecoveryResolution?
    ) -> CityStrategyHUDPresentation {
        let diagnostic = CityDirectResponse(
            title: "Tax policy & cashflow",
            command: .inspectorFinances,
            explanation: "Review current tax policy, revenue, and upkeep through the existing Command Center.",
            focusesMap: false
        )
        let actions = [
            CityDirectResponse(
                title: "Review tax policy",
                command: .inspectorFinances,
                explanation: "Tax relief may support demand but reduces revenue.",
                focusesMap: false
            ),
            CityDirectResponse(
                title: "Build a park",
                command: .buildPark,
                explanation: "Select Park and return focus to the map; placement does not guarantee recovery.",
                focusesMap: true
            )
        ]

        switch phase {
        case .opportunity:
            return .init(
                eyebrow: "MAIN STREET STRATEGY",
                title: "Commercial stewardship",
                status: timedStatus("OPPORTUNITY", days: days),
                summary: "The route is committed. Prepare tax policy or public space before the next market turn.",
                tone: .active,
                diagnostic: diagnostic,
                actions: actions
            )
        case .complication:
            return .init(
                eyebrow: "MAIN STREET STRATEGY",
                title: "Protect local storefronts",
                status: timedStatus("DECISION", days: days),
                summary: "Diagnose cashflow, then choose tax relief or a park before the consequence.",
                tone: .active,
                diagnostic: diagnostic,
                actions: actions
            )
        case .setback:
            return .init(
                eyebrow: "MAIN STREET URGENT",
                title: "Storefront consequence pending",
                status: timedStatus("ACT NOW", days: days),
                summary: "Use Tax Policy or place a park while the authoritative decision window remains open.",
                tone: .urgent,
                diagnostic: diagnostic,
                actions: actions
            )
        case .recovery:
            let resolutionText = resolution.map(resolutionTitle) ?? "No recovery choice is locked in"
            return .init(
                eyebrow: "MAIN STREET RECOVERY",
                title: resolutionText,
                status: timedStatus("REVIEW", days: days),
                summary: resolution == nil
                    ? "The route remains recoverable. Diagnose cashflow and take a legitimate action before review."
                    : "The accepted recovery is recorded. Watch its payoff and the citywide operating result.",
                tone: .recovery,
                diagnostic: diagnostic,
                actions: resolution == nil ? actions : []
            )
        case .completed:
            return .init(
                eyebrow: "MAIN STREET RESULT",
                title: resolution.map(resolutionTitle) ?? "Commercial story complete",
                status: "STORY COMPLETE",
                summary: "The commercial outcome is recorded in the authoritative city state.",
                tone: .resolved,
                diagnostic: diagnostic,
                actions: []
            )
        }
    }

    private static func industrial(
        phase: CityStrategyPhase,
        days: Int?,
        resolution: CityStrategyRecoveryResolution?
    ) -> CityStrategyHUDPresentation {
        let diagnostic = CityDirectResponse(
            title: "Utility capacity",
            command: .inspectorUtilities,
            explanation: "Review current power, water, coverage, and reserve through the existing Command Center.",
            focusesMap: false
        )
        let actions = [
            CityDirectResponse(
                title: "Add power",
                command: .buildPowerPlant,
                explanation: "Select Power Plant and return focus to the map; placement does not guarantee recovery.",
                focusesMap: true
            ),
            CityDirectResponse(
                title: "Add water",
                command: .buildWaterTower,
                explanation: "Select Water Tower and return focus to the map; placement does not guarantee recovery.",
                focusesMap: true
            ),
            CityDirectResponse(
                title: "Add green buffer",
                command: .buildPark,
                explanation: "Select Park and return focus to the map; placement does not guarantee recovery.",
                focusesMap: true
            )
        ]

        switch phase {
        case .opportunity:
            return .init(
                eyebrow: "FREIGHT STRATEGY",
                title: "Industrial expansion",
                status: timedStatus("OPPORTUNITY", days: days),
                summary: "The route is committed. Prepare utility capacity or a green buffer before freight load rises.",
                tone: .active,
                diagnostic: diagnostic,
                actions: actions
            )
        case .complication:
            return .init(
                eyebrow: "FREIGHT STRATEGY",
                title: "Prepare for the load surge",
                status: timedStatus("DECISION", days: days),
                summary: "Diagnose utilities, then add capacity or a park before the consequence.",
                tone: .active,
                diagnostic: diagnostic,
                actions: actions
            )
        case .setback:
            return .init(
                eyebrow: "FREIGHT URGENT",
                title: "Freight consequence pending",
                status: timedStatus("ACT NOW", days: days),
                summary: "Add reserve power and water or place a green buffer while the decision window remains open.",
                tone: .urgent,
                diagnostic: diagnostic,
                actions: actions
            )
        case .recovery:
            let resolutionText = resolution.map(resolutionTitle) ?? "No recovery choice is locked in"
            return .init(
                eyebrow: "FREIGHT RECOVERY",
                title: resolutionText,
                status: timedStatus("REVIEW", days: days),
                summary: resolution == nil
                    ? "The route remains recoverable. Diagnose utilities and take a legitimate action before review."
                    : "The accepted recovery is recorded. Watch its payoff and the citywide operating result.",
                tone: .recovery,
                diagnostic: diagnostic,
                actions: resolution == nil ? actions : []
            )
        case .completed:
            return .init(
                eyebrow: "FREIGHT RESULT",
                title: resolution.map(resolutionTitle) ?? "Industrial story complete",
                status: "STORY COMPLETE",
                summary: "The industrial outcome is recorded in the authoritative city state.",
                tone: .resolved,
                diagnostic: diagnostic,
                actions: []
            )
        }
    }

    private static func timedStatus(_ label: String, days: Int?) -> String {
        guard let days else { return label }
        if days == 0 { return "\(label) · TODAY" }
        if days == 1 { return "\(label) · 1 DAY" }
        return "\(label) · \(days) DAYS"
    }

    private static func resolutionTitle(_ resolution: CityStrategyRecoveryResolution) -> String {
        switch resolution {
        case .commercialTaxRelief: "Tax relief locked in"
        case .commercialPublicRealmInvestment: "Public realm investment locked in"
        case .industrialUtilityExpansion: "Utility expansion locked in"
        case .industrialGreenBuffer: "Green buffer locked in"
        }
    }
}

struct HUDConsequenceFeedbackPresentation: Equatable {
    enum Direction: Equatable {
        case positive
        case negative
        case neutral

        var sign: String {
            switch self {
            case .positive: "+"
            case .negative: "−"
            case .neutral: "•"
            }
        }
    }

    let message: CityMessage
    let direction: Direction

    var visualText: String {
        "\(direction.sign) \(message.title) · \(message.detail)"
    }

    var accessibilityValue: String {
        "\(direction.sign) \(message.title). \(message.detail)"
    }

    static func make(from messages: [CityMessage]) -> HUDConsequenceFeedbackPresentation? {
        guard let message = messages.first, materialTitles.contains(message.title) else {
            return nil
        }

        let direction: Direction = switch message.severity {
        case .good: .positive
        case .warning, .critical: .negative
        case .information: .neutral
        }
        return HUDConsequenceFeedbackPresentation(message: message, direction: direction)
    }

    private static let materialTitles: Set<String> = [
        "Severe Storm",
        "Storm Recovery Complete",
        "Storefront Slump",
        "Main Street Recovery Delayed",
        "Main Street Rebound",
        "Industrial Load Surge",
        "Industrial Load Absorbed",
        "Utility Reserve Tight",
        "Utility Shortfall",
        "Regional Retail Pressure",
        "Regional Main Street Recovery",
        "Regional Grid Mandate",
        "Regional Freight Overload",
        "Regional Freight Recovery",
        "Regional Capital Recognized"
    ]
}

struct StrategyCommandCenterView: View {
    @ObservedObject var store: CityGameStore
    var compact = false

    static let compactMaximumHeight: CGFloat = 48
    static let regularMaximumHeight: CGFloat = 52

    private var presentation: CityStrategyHUDPresentation {
        CityStrategyHUDPresentation.make(analytics: store.analytics)
    }

    private var trajectory: CityTrajectoryHUDPresentation {
        CityTrajectoryHUDPresentation.make(projectedBalance: store.analytics.projectedBalance)
    }

    private var consequenceFeedback: HUDConsequenceFeedbackPresentation? {
        HUDConsequenceFeedbackPresentation.make(from: store.state.messages)
    }

    private var primaryResponse: CityDirectResponse? {
        presentation.diagnostic ?? presentation.actions.first
    }

    private var secondaryResponses: [CityDirectResponse] {
        guard presentation.diagnostic == nil else { return presentation.actions }
        return Array(presentation.actions.dropFirst())
    }

    private var directRemedy: CityDirectResponse? {
        guard let feedback = consequenceFeedback,
              feedback.message.severity == .warning || feedback.message.severity == .critical else {
            return nil
        }
        return CityNoticeActionCatalog.actions(
            for: feedback.message.title,
            analytics: store.analytics
        ).first
    }

    var body: some View {
        HStack(alignment: .center, spacing: compact ? 6 : 8) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(presentation.eyebrow)
                        .font(.system(size: GameTheme.hudCriticalTextSize, weight: .heavy, design: .rounded))
                        .tracking(0.25)
                        .foregroundStyle(tint)
                    Text(presentation.status)
                        .font(.system(size: GameTheme.hudCriticalTextSize, weight: .heavy, design: .rounded).monospacedDigit())
                        .lineLimit(1)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(tint.opacity(0.16), in: Capsule())
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(presentation.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .lineLimit(1)
                    if !compact {
                        if let consequenceFeedback {
                            consequenceRow(consequenceFeedback)
                        } else {
                            Text(presentation.summary)
                                .font(.system(size: GameTheme.hudSupportTextSize, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .accessibilityHidden(true)
                        }
                    }
                }
                if compact, let consequenceFeedback {
                    consequenceRow(consequenceFeedback)
                }
            }

            Spacer(minLength: 2)

            HStack(spacing: 4) {
                Label(trajectory.label, systemImage: trajectory.symbol)
                    .font(.system(size: GameTheme.hudCriticalTextSize, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(trajectory.isPositive ? GameTheme.accent : GameTheme.danger)
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .frame(minHeight: GameTheme.controlMinimum)
                    .background(
                        (trajectory.isPositive ? GameTheme.accent : GameTheme.danger).opacity(0.13),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                    .accessibilityLabel("City trajectory")
                    .accessibilityValue(trajectory.accessibilityValue)
                    .accessibilityIdentifier("hud.city.trajectory")
                if let primaryResponse {
                    primaryResponseButton(primaryResponse)
                }
                if !secondaryResponses.isEmpty {
                    responseMenu
                }
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: compact ? Self.compactMaximumHeight : Self.regularMaximumHeight)
        .background(
            GameTheme.hudRaisedFill.opacity(0.88),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(tint.opacity(0.48), lineWidth: presentation.tone == .urgent ? 1.5 : 1)
        )
        .help(consequenceFeedback?.message.detail ?? presentation.summary)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("City priority: \(presentation.title)")
        .accessibilityValue(
            [presentation.accessibilityValue, consequenceFeedback?.accessibilityValue]
                .compactMap { $0 }
                .joined(separator: ". ")
        )
        .accessibilityIdentifier("hud.strategy.priority")
    }

    private var consequenceTint: Color {
        guard let consequenceFeedback else { return .secondary }
        return switch consequenceFeedback.direction {
        case .positive: GameTheme.accent
        case .negative: GameTheme.warning
        case .neutral: .secondary
        }
    }

    private func consequenceCue(_ feedback: HUDConsequenceFeedbackPresentation) -> some View {
        Button {
            store.openMessage(feedback.message)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "bell.badge.fill")
                    .accessibilityHidden(true)
                Text("Latest \(feedback.visualText)")
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .font(.system(size: GameTheme.hudSupportTextSize, weight: .semibold))
            .foregroundStyle(consequenceTint)
            .padding(.horizontal, 4)
            .frame(minHeight: 24)
            .background(consequenceTint.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .layoutPriority(1)
        .help("Open the latest consequence: \(feedback.message.title)")
        .accessibilityLabel("Open latest consequence: \(feedback.message.title)")
        .accessibilityValue(feedback.accessibilityValue)
        .accessibilityHint("Opens the related city details")
        .accessibilityIdentifier("hud.strategy.consequence")
    }

    @ViewBuilder
    private func consequenceRow(_ feedback: HUDConsequenceFeedbackPresentation) -> some View {
        HStack(spacing: 5) {
            consequenceCue(feedback)
            if let directRemedy {
                Button {
                    Self.perform(directRemedy, on: store)
                } label: {
                    Label(compact ? "Act" : "Act: " + directRemedy.title, systemImage: "arrow.right.circle.fill")
                        .font(.system(size: GameTheme.hudSupportTextSize, weight: .bold))
                        .lineLimit(1)
                        .padding(.horizontal, compact ? 5 : 7)
                        .frame(minHeight: GameTheme.controlMinimum)
                }
                .buttonStyle(.borderedProminent)
                .tint(GameTheme.warning)
                .help(directRemedy.explanation)
                .accessibilityLabel("Act on " + feedback.message.title + ": " + directRemedy.title)
                .accessibilityHint(
                    directRemedy.explanation + (directRemedy.focusesMap ? " Focus returns to the map." : "")
                )
                .accessibilityIdentifier("hud.strategy.remedy")
            }
        }
    }

    private func primaryResponseButton(_ response: CityDirectResponse) -> some View {
        let compactTitle = Self.recoveryRouteTitle(for: response, compact: compact)
        let outcome = Self.recoveryRouteOutcome(for: response)
        return Button { perform(response) } label: {
            HStack(spacing: 3) {
                Image(systemName: "arrow.right.circle.fill")
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Next: \(compactTitle)")
                        .font(.system(size: GameTheme.hudCriticalTextSize, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(outcome)
                        .font(.system(size: GameTheme.hudSupportTextSize, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .padding(.horizontal, compact ? 4 : 7)
            .frame(minWidth: compact ? 76 : 116, minHeight: GameTheme.controlMinimum)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .disabled(!store.canPerform(response.command))
        .help(store.disabledReason(for: response.command) ?? response.explanation)
        .accessibilityLabel(Self.recoveryRouteTitle(for: response, compact: false))
        .accessibilityValue(outcome)
        .accessibilityHint(response.explanation)
        .accessibilityIdentifier("hud.strategy.primary")
    }

    static func recoveryRouteTitle(for response: CityDirectResponse, compact: Bool) -> String {
        switch response.command {
        case .inspectorFinances:
            return compact ? "Tax Policy" : "Open Tax Policy"
        case .inspectorUtilities:
            return compact ? "Utilities" : "Open Utilities"
        case .buildPark:
            return compact ? "Build Park" : "Build a Park"
        case .buildPowerPlant:
            return compact ? "Add Power" : "Add Power Plant"
        case .buildWaterTower:
            return compact ? "Add Water" : "Add Water Tower"
        default:
            return response.title
        }
    }

    static func recoveryRouteOutcome(for response: CityDirectResponse) -> String {
        switch response.command {
        case .inspectorFinances:
            return "Tax relief may support demand; revenue may fall."
        case .inspectorUtilities:
            return "More capacity may protect the grid."
        case .buildPark:
            return "A park may support recovery; placement is not guaranteed."
        case .buildPowerPlant:
            return "Reserve power may protect freight; placement is not guaranteed."
        case .buildWaterTower:
            return "Water reserve may protect freight; placement is not guaranteed."
        default:
            return response.explanation
        }
    }

    private var responseMenu: some View {
        Menu {
            ForEach(secondaryResponses) { response in
                let title = Self.recoveryRouteTitle(for: response, compact: false)
                let outcome = Self.recoveryRouteOutcome(for: response)
                Button { perform(response) } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                        Text(outcome)
                            .font(.caption)
                    }
                }
                    .disabled(!store.canPerform(response.command))
                    .accessibilityLabel(title)
                    .accessibilityValue(outcome)
                    .accessibilityHint(
                        store.disabledReason(for: response.command) ?? response.explanation
                    )
            }
        } label: {
            Label(compact ? "Routes" : "Recovery routes", systemImage: "arrow.turn.down.right")
                .font(.system(size: GameTheme.hudCriticalTextSize, weight: .bold))
                .frame(minWidth: GameTheme.controlMinimum, minHeight: GameTheme.controlMinimum)
        }
        .menuStyle(.borderlessButton)
        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel("Recovery routes for \(presentation.title)")
        .accessibilityValue("\(secondaryResponses.count) routes with destination and likely outcome")
    }

    private func perform(_ response: CityDirectResponse) {
        Self.perform(response, on: store)
    }

    @MainActor
    static func perform(_ response: CityDirectResponse, on store: CityGameStore) {
        let performed: Bool
        if response.focusesMap {
            performed = store.performMapFocused(response.command)
        } else {
            performed = store.perform(response.command)
        }
        if performed {
            // Strategy responses are deliberate management decisions. Freeze
            // the clock while the player inspects the destination or chooses
            // an exact parcel, preserving their prior speed for Space-resume.
            store.setSpeed(.paused)
        }
    }

    private var symbol: String {
        switch presentation.tone {
        case .decision: "signpost.right.and.left.fill"
        case .active: "scope"
        case .urgent: "exclamationmark.triangle.fill"
        case .recovery: "arrow.trianglehead.2.clockwise.rotate.90"
        case .resolved: "checkmark.seal.fill"
        }
    }

    private var tint: Color {
        switch presentation.tone {
        case .decision: GameTheme.information
        case .active: GameTheme.warning
        case .urgent: GameTheme.danger
        case .recovery: GameTheme.accent
        case .resolved: GameTheme.accent
        }
    }
}

struct CityTrajectoryHUDPresentation: Equatable {
    let label: String
    let symbol: String
    let accessibilityValue: String
    let isPositive: Bool

    static func make(projectedBalance: Double) -> Self {
        if projectedBalance > 0 {
            return Self(
                label: "\(projectedBalance.signedCurrencyText) / cycle",
                symbol: "arrow.up.right",
                accessibilityValue: "Growing by \(projectedBalance.currencyText) per cycle",
                isPositive: true
            )
        }
        if projectedBalance < 0 {
            return Self(
                label: "\(projectedBalance.signedCurrencyText) / cycle",
                symbol: "arrow.down.right",
                accessibilityValue: "Losing \(abs(projectedBalance).currencyText) per cycle",
                isPositive: false
            )
        }
        return Self(
            label: "$0 / cycle",
            symbol: "arrow.right",
            accessibilityValue: "Holding steady",
            isPositive: true
        )
    }
}
