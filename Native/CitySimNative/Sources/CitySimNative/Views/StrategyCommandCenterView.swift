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
              let strategy = analytics.committedStrategy,
              let phase = analytics.strategyPhase else {
            return CityStrategyHUDPresentation(
                eyebrow: "CITY PRIORITY",
                title: "Choose a growth engine",
                status: "DECISION READY",
                summary: "Commit Commercial for steadier growth or Industrial for a faster, higher-pressure return.",
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
                status: timedStatus("DECISION WINDOW", days: days),
                summary: "Diagnose cashflow, then choose tax relief or a park before the chain-store consequence.",
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
                status: timedStatus("DECISION WINDOW", days: days),
                summary: "Diagnose utilities, then add reserve capacity or a park before the freight consequence.",
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

struct StrategyCommandCenterView: View {
    @ObservedObject var store: CityGameStore
    var compact = false

    static let compactMaximumHeight: CGFloat = 112

    private var presentation: CityStrategyHUDPresentation {
        CityStrategyHUDPresentation.make(analytics: store.analytics)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 9))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(presentation.eyebrow)
                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                        .tracking(0.7)
                        .foregroundStyle(tint)
                    Text(presentation.status)
                        .font(.system(size: 8, weight: .heavy, design: .rounded).monospacedDigit())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(tint.opacity(0.16), in: Capsule())
                }
                Text(presentation.title)
                    .font(.callout.weight(.bold))
                    .lineLimit(1)
                Text(presentation.summary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(compact ? 2 : 2)
            }

            Spacer(minLength: 2)

            VStack(spacing: 4) {
                if let diagnostic = presentation.diagnostic {
                    responseButton(diagnostic)
                }
                if !presentation.actions.isEmpty {
                    responseMenu
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: compact ? 390 : 430, alignment: .leading)
        .frame(maxHeight: compact ? Self.compactMaximumHeight : nil)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(tint.opacity(0.7), lineWidth: presentation.tone == .urgent ? 2 : 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 12, y: 5)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("City priority: \(presentation.title)")
        .accessibilityValue(presentation.accessibilityValue)
        .accessibilityIdentifier("hud.strategy.priority")
    }

    private func responseButton(_ response: CityDirectResponse) -> some View {
        Button { perform(response) } label: {
            Label(response.title, systemImage: "waveform.path.ecg.rectangle")
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .frame(minWidth: GameTheme.controlMinimum, minHeight: GameTheme.controlMinimum)
        }
        .buttonStyle(.bordered)
        .disabled(!store.canPerform(response.command))
        .help(store.disabledReason(for: response.command) ?? response.explanation)
        .accessibilityHint(response.explanation)
    }

    private var responseMenu: some View {
        Menu {
            ForEach(presentation.actions) { response in
                Button(response.title) { perform(response) }
                    .disabled(!store.canPerform(response.command))
                    .accessibilityHint(
                        store.disabledReason(for: response.command) ?? response.explanation
                    )
            }
        } label: {
            Label("Act", systemImage: "arrow.turn.down.right")
                .font(.caption2.weight(.bold))
                .frame(minWidth: GameTheme.controlMinimum, minHeight: GameTheme.controlMinimum)
        }
        .menuStyle(.borderlessButton)
        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel("Act on \(presentation.title)")
        .accessibilityValue("\(presentation.actions.count) available routes")
    }

    private func perform(_ response: CityDirectResponse) {
        if response.focusesMap {
            store.performMapFocused(response.command)
        } else {
            store.perform(response.command)
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
